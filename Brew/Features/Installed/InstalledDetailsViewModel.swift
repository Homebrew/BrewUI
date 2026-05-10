//
//  InstalledDetailsViewModel.swift
//  Brew
//

import Foundation
import Observation

@Observable
@MainActor
final class InstalledDetailsViewModel {
    private let brewCommandCenter: any BrewCommandCenter
    private var upgradeTask: Task<Void, Never>?

    private(set) var package: BrewPackage
    /// Snapshot from ``BrewCommandCenter/phase(for:)`` for this row’s ``BrewOperationID``,
    /// updated from ``observeRowUpdates()`` (initial yield plus each phase transition from the command center).
    private(set) var upgradeOperationPhase: BrewOperationPhase = .idle
    /// Inline message when upgrade fails; cleared when a new upgrade starts.
    private(set) var upgradeErrorMessage: String?

    /// True while upgrade work is in flight (`CONVENTIONS.md` — transparency / guardrails).
    private(set) var isUpgrading: Bool = false

    var packageName: String {
        package.name
    }

    var packageKind: InstalledPackageKind {
        package.kind
    }

    /// User-facing command for the currently selected package details.
    var displayCommand: String {
        package.infoCommand
    }

    /// Copyable Terminal command for upgrading this package (`CONVENTIONS.md` — transparency).
    var upgradeDisplayCommand: String {
        package.upgradeCommand
    }

    /// Shown beside the upgrade affordance whenever the package is outdated.
    var showsUpgradeChrome: Bool {
        package.outdated
    }

    var upgradePrimaryButtonTitle: String? {
        package.upgradeButtonTitle
    }

    /// Valid homepage URL for display, if available.
    var homepageURL: URL? {
        package.homepageURL
    }

    init(
        package: BrewPackage,
        brewCommandCenter: any BrewCommandCenter,
    ) {
        self.package = package
        self.brewCommandCenter = brewCommandCenter
    }

    /// Syncs snapshot data for this row (`InstalledListRowViewModel/update(package:)` pattern).
    func update(package newPackage: BrewPackage) {
        guard newPackage != package else {
            return
        }
        package = newPackage
        upgradeErrorMessage = nil
    }

    func upgradeSelectedPackage() {
        guard !isUpgrading else {
            return
        }

        upgradeErrorMessage = nil
        let operationID = BrewOperationID(kind: package.kind, name: package.name)
        let command = PackageUpgradeCommand(kind: package.kind, name: package.name)

        upgradeTask?.cancel()
        upgradeTask = Task { @MainActor [self] in
            do {
                try await brewCommandCenter.submit(id: operationID, command: command)
            } catch {
                let latestPhase = await brewCommandCenter.phase(for: operationID)
                if case let .failed(reason: failure) = latestPhase {
                    upgradeErrorMessage = failure.userFacingMessage
                } else {
                    upgradeErrorMessage = Self.userMessage(for: error)
                }
            }
        }
    }

    /// Run while the installed detail column shows this ``package/id`` (`InstalledListRowView` pattern).
    func observeRowUpdates() async {
        let operationID = BrewOperationID(package: package)
        let stream = await brewCommandCenter.phaseChanges(for: operationID)
        for await phase in stream {
            let oldPhase = upgradeOperationPhase
            upgradeOperationPhase = phase
            isUpgrading = InstalledUpgradeBusyPresentation.showsUpgradeBusy(
                oldPhase: oldPhase,
                newPhase: phase,
                isPackageOutdated: package.outdated,
            )
        }
    }

    private static func userMessage(for error: Error) -> String {
        switch error {
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
            return String(
                localized: "Something went wrong while upgrading this package.",
                comment: "Installed detail generic upgrade error",
            )
        }
    }
}
