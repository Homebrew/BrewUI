//
//  InstalledDetailsViewModel.swift
//  Brew
//

import Foundation
import Observation

enum InstalledDetailsLoadState: Equatable {
    case loading
    case loaded(InstalledPackageDetails)
    case error(String)
}

@Observable
@MainActor
final class InstalledDetailsViewModel {
    private let repository: PackageDetailsRepository
    private let brewCommandCenter: any BrewCommandCenter
    private let onUpgradeSuccess: (@MainActor () async -> Void)?
    private var loadTask: Task<Void, Never>?
    private var upgradeTask: Task<Void, Never>?
    private var requestID: Int = 0

    private(set) var state: InstalledDetailsLoadState = .loading
    /// Snapshot from ``BrewCommandCenter/phase(for:)`` for this row’s ``BrewOperationID``, refreshed on detail load
    /// and around ``BrewCommandCenter/submit`` (plus a brief optimistic ``BrewOperationPhase/running(_:)`` while awaiting submit).
    private(set) var upgradeOperationPhase: BrewOperationPhase = .idle
    /// Inline message when upgrade fails; cleared when a new upgrade starts.
    private(set) var upgradeErrorMessage: String?

    let selection: PackageSelection

    /// True while upgrade work is in flight (`CONVENTIONS.md` — transparency / guardrails).
    var isUpgrading: Bool {
        if case .running = upgradeOperationPhase {
            return true
        }
        return false
    }

    var packageName: String {
        if case let .loaded(details) = state {
            return details.name
        }
        return selection.name
    }

    var packageKind: InstalledPackageKind {
        if case let .loaded(details) = state {
            return details.kind
        }
        return selection.kind
    }

    /// User-facing command for the currently selected package details.
    var displayCommand: String {
        "brew info \(packageName)"
    }

    /// Copyable Terminal command for upgrading this package (`CONVENTIONS.md` — transparency).
    var upgradeDisplayCommand: String {
        Self.userFacingUpgradeCommand(name: packageName, kind: packageKind)
    }

    /// Shown beside the upgrade affordance whenever loaded details report an outdated package.
    var showsUpgradeChrome: Bool {
        if case let .loaded(details) = state {
            return details.outdated
        }
        return false
    }

    var upgradePrimaryButtonTitle: String? {
        guard case let .loaded(details) = state else {
            return nil
        }
        guard details.outdated else {
            return nil
        }
        guard let label = InstalledBrewVersionFormatting.upgradeDisplayLabel(from: details.availableVersion) else {
            return nil
        }
        return String(
            localized: "Update to \(label)",
            comment: "Installed detail upgrade button; interpolated label shows target tap version.",
        )
    }

    /// Valid homepage URL for display, if available.
    var homepageURL: URL? {
        guard case let .loaded(details) = state else {
            return nil
        }
        return Self.validWebURL(from: details.homepage)
    }

    init(
        selection: PackageSelection,
        repository: any PackageDetailsRepository,
        brewCommandCenter: any BrewCommandCenter,
        onUpgradeSuccess: (@MainActor () async -> Void)? = nil,
    ) {
        self.selection = selection
        self.repository = repository
        self.brewCommandCenter = brewCommandCenter
        self.onUpgradeSuccess = onUpgradeSuccess
    }

    func load() {
        loadTask?.cancel()
        requestID += 1
        let activeRequestID = requestID

        state = .loading

        loadTask = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let details = try await repository.loadPackageDetails(
                    named: selection.name,
                    preferredKind: selection.kind,
                )
                guard !Task.isCancelled else {
                    return
                }
                applyResult(requestID: activeRequestID, state: .loaded(details))
                await syncUpgradePhaseFromCommandCenter()
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                applyResult(
                    requestID: activeRequestID,
                    state: .error(Self.userMessage(for: error, context: .loadDetails)),
                )
                await syncUpgradePhaseFromCommandCenter()
            }
        }
    }

    func upgradeSelectedPackage() {
        guard !isUpgrading else {
            return
        }

        upgradeErrorMessage = nil
        let operationID = BrewOperationID(kind: selection.kind, name: selection.name)
        let command = PackageUpgradeCommand(kind: selection.kind, name: selection.name)

        upgradeOperationPhase = .running(command.operationKind)

        upgradeTask?.cancel()
        upgradeTask = Task { [self, brewCommandCenter, onUpgradeSuccess] in
            do {
                try await brewCommandCenter.submit(id: operationID, command: command)
                await onUpgradeSuccess?()
                await refresh()
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                await MainActor.run {
                    upgradeOperationPhase = latestPhase
                }
            } catch {
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                await MainActor.run {
                    upgradeOperationPhase = latestPhase
                    if case let .failed(reason: failure) = latestPhase {
                        upgradeErrorMessage = failure.userFacingMessage
                    } else {
                        upgradeErrorMessage = Self.userMessage(for: error, context: .runUpgrade)
                    }
                }
            }
        }
    }

    private func syncUpgradePhaseFromCommandCenter() async {
        let operationID = BrewOperationID(kind: selection.kind, name: selection.name)
        upgradeOperationPhase = await brewCommandCenter.phase(for: operationID)
    }

    private func refresh() async {
        requestID += 1
        let activeRequestID = requestID

        do {
            let details = try await repository.loadPackageDetails(
                named: selection.name,
                preferredKind: selection.kind,
            )
            guard !Task.isCancelled else {
                return
            }
            applyResult(requestID: activeRequestID, state: .loaded(details))
            await syncUpgradePhaseFromCommandCenter()
        } catch {
            guard !Task.isCancelled else {
                return
            }
            // Keep current loaded state visible; refresh errors are non-blocking.
        }
    }

    private func applyResult(requestID: Int, state: InstalledDetailsLoadState) {
        guard self.requestID == requestID else {
            return
        }
        self.state = state
    }

    private static func userFacingUpgradeCommand(name: String, kind: InstalledPackageKind) -> String {
        switch kind {
        case .formula:
            "brew upgrade \(name)"
        case .cask:
            "brew upgrade --cask \(name)"
        }
    }

    private enum UserMessageContext {
        case loadDetails
        case runUpgrade
    }

    private static func userMessage(for error: Error, context: UserMessageContext) -> String {
        switch error {
        case PackageDetailsRepositoryError.packageNotFound:
            return String(
                localized: "Could not load package details from Homebrew.",
                comment: "Installed detail error when package is missing in brew info JSON response",
            )
        case PackageDetailsRepositoryError.invalidJSONOutput:
            return String(
                localized: "Homebrew returned invalid package details.",
                comment: "Installed detail error when brew info JSON cannot be decoded",
            )
        case BrewLookupError.executableNotFound:
            return String(
                localized: "Could not find Homebrew. Install it or ensure brew is in the default location.",
                comment: "Installed detail error when brew binary missing",
            )
        case let BrewCommandError.failed(_, stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            return String(localized: "Homebrew command failed.", comment: "Installed detail generic brew failure")
        case let BrewCommandError.launchFailed(underlying):
            return underlying
        default:
            switch context {
            case .loadDetails:
                return String(
                    localized: "Something went wrong loading package details.",
                    comment: "Installed detail generic load error",
                )
            case .runUpgrade:
                return String(
                    localized: "Something went wrong while upgrading this package.",
                    comment: "Installed detail generic upgrade error",
                )
            }
        }
    }

    private static func validWebURL(from rawValue: String?) -> URL? {
        guard let rawValue else {
            return nil
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        else {
            return nil
        }
        return url
    }
}
