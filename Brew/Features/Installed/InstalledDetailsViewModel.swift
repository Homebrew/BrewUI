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
    private let repository: (any PackageDetailsRepository)?
    private let selectedRow: InstalledPackageRow
    private var loadTask: Task<Void, Never>?
    private var requestID: Int = 0

    private(set) var state: InstalledDetailsLoadState = .loading

    var packageName: String {
        if case let .loaded(details) = state {
            return details.name
        }
        return selectedRow.name
    }

    var packageKind: InstalledPackageKind {
        if case let .loaded(details) = state {
            return details.kind
        }
        return selectedRow.kind
    }

    /// User-facing command for the currently selected package details.
    var displayCommand: String {
        "brew info \(packageName)"
    }

    init(selectedRow: InstalledPackageRow, repository: any PackageDetailsRepository) {
        self.selectedRow = selectedRow
        self.repository = repository
    }

    init(
        testingSelectedRow: InstalledPackageRow,
        state: InstalledDetailsLoadState = .loading,
    ) {
        selectedRow = testingSelectedRow
        repository = nil
        self.state = state
    }

    func load() {
        guard let repository else {
            return
        }
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
                    named: selectedRow.name,
                    preferredKind: selectedRow.kind,
                )
                guard !Task.isCancelled else {
                    return
                }
                await self.applyResult(requestID: activeRequestID, state: .loaded(details))
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                await self.applyResult(requestID: activeRequestID, state: .error(Self.userMessage(for: error)))
            }
        }
    }

    private func applyResult(requestID: Int, state: InstalledDetailsLoadState) {
        guard self.requestID == requestID else {
            return
        }
        self.state = state
    }

    private static func userMessage(for error: Error) -> String {
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
            return String(
                localized: "Something went wrong loading package details.",
                comment: "Installed detail generic load error",
            )
        }
    }
}
