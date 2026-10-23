//
//  CleanupViewModel.swift
//  BrewFeatureCleanup
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

/// Coarse view-facing projection of the preview, so the view binds to one decision per state
/// (`AGENTS.md` — passive views).
enum CleanupPresentation: Equatable {
    case loading
    case clean
    case removable
    case failed(String)
}

@Observable
@MainActor
final class CleanupViewModel {
    @ObservationIgnored private let repository: any CleanupRepository
    @ObservationIgnored private let commandCenter: any BrewCommandCenter
    @ObservationIgnored private let commandFactory: any BrewMutatingCommandFactory
    @ObservationIgnored private var cleanupTask: Task<Void, Never>?

    /// Adds `--prune=all` to both the preview and the run, so what runs is what was reviewed.
    private(set) var pruneAll = false
    private(set) var isCleaningUp = false
    private(set) var cleanupErrorMessage: String?
    var showsCleanupConfirmation = false

    init(
        repository: any CleanupRepository,
        commandCenter: any BrewCommandCenter,
        commandFactory: any BrewMutatingCommandFactory,
    ) {
        self.repository = repository
        self.commandCenter = commandCenter
        self.commandFactory = commandFactory
    }

    // MARK: - Derived state

    var state: LoadState<CleanupReport, String> {
        switch repository.state {
        case .loading:
            .loading
        case let .loaded(report):
            .loaded(report)
        case let .failed(error):
            .failed(Self.message(for: error))
        }
    }

    var presentation: CleanupPresentation {
        switch state {
        case .loading:
            .loading
        case let .loaded(report):
            report.isEmpty ? .clean : .removable
        case let .failed(message):
            .failed(message)
        }
    }

    var isRefreshing: Bool {
        repository.isRefreshing
    }

    var refreshFailureMessage: String? {
        repository.refreshFailure.map(Self.message(for:))
    }

    var subtitle: LocalizedStringResource {
        if isCleaningUp {
            return LocalizedStringResource("Cleaning up…", bundle: #bundle, comment: "Cleanup subtitle while brew cleanup runs")
        }
        switch presentation {
        case .loading:
            return LocalizedStringResource("Checking what can be removed…", bundle: #bundle, comment: "Cleanup subtitle during the first dry run")
        case .clean:
            return LocalizedStringResource("Nothing to remove", bundle: #bundle, comment: "Cleanup subtitle when the dry run found nothing")
        case .removable:
            return LocalizedStringResource("Review what Homebrew would remove", bundle: #bundle, comment: "Cleanup subtitle when the dry run found items")
        case .failed:
            return LocalizedStringResource("The check could not be completed", bundle: #bundle, comment: "Cleanup subtitle when the dry run failed")
        }
    }

    /// The literal `brew cleanup` the button runs, shown so it can be copied to Terminal.
    var cleanupDisplayCommand: String {
        commandFactory.cleanupCommand(pruneAll: pruneAll).displayCommand
    }

    var canCleanUp: Bool {
        presentation == .removable && !isCleaningUp && !isRefreshing
    }

    /// Header controls act on a loaded preview, so they wait for one rather than racing the first run.
    var showsHeaderControls: Bool {
        switch presentation {
        case .clean, .removable:
            true
        case .loading, .failed:
            false
        }
    }

    func headline(for report: CleanupReport) -> String {
        if let space = report.reclaimableSpace {
            return String(
                localized: "About \(space) can be freed",
                bundle: #bundle,
                comment: "Cleanup summary; %@ is Homebrew's disk-space total, e.g. 67.5MB",
            )
        }
        return String(localized: "Ready to clean up", bundle: #bundle, comment: "Cleanup summary when Homebrew printed no disk-space total")
    }

    func unneededFormulaeTitle(for report: CleanupReport) -> String {
        let count = report.unneededFormulae.count
        return count == 1
            ? String(localized: "1 unneeded dependency", bundle: #bundle, comment: "Cleanup section title, one formula")
            : String(localized: "\(count) unneeded dependencies", bundle: #bundle, comment: "Cleanup section title; %lld is the formula count")
    }

    func removalsTitle(for report: CleanupReport) -> String {
        let count = report.removals.count
        return count == 1
            ? String(localized: "1 old version, download or log", bundle: #bundle, comment: "Cleanup section title, one path")
            : String(localized: "\(count) old versions, downloads and logs", bundle: #bundle, comment: "Cleanup section title; %lld is the path count")
    }

    func removalItems(for report: CleanupReport) -> [CleanupRemovalItem] {
        report.removals.map(CleanupRemovalItem.init(removal:))
    }

    /// Says what cannot be undone: autoremove uninstalls, and removed old versions are gone for good.
    var confirmationMessage: String {
        guard let report = state.value, !report.unneededFormulae.isEmpty else {
            return String(
                localized: "Old versions and cached downloads are deleted and cannot be restored.",
                bundle: #bundle,
                comment: "Cleanup confirmation message when no formulae will be uninstalled",
            )
        }
        let formulae = report.unneededFormulae.joined(separator: ", ")
        return String(
            localized: "This also uninstalls \(formulae). Old versions and cached downloads are deleted and cannot be restored.",
            bundle: #bundle,
            comment: "Cleanup confirmation message; %@ is a comma-separated list of formula names",
        )
    }

    // MARK: - Intents

    func load() async {
        await repository.load(pruneAll: pruneAll)
    }

    func setPruneAll(_ pruneAll: Bool) async {
        guard pruneAll != self.pruneAll else {
            return
        }
        self.pruneAll = pruneAll
        await load()
    }

    func requestCleanup() {
        guard canCleanUp else {
            return
        }
        showsCleanupConfirmation = true
    }

    /// Runs `brew cleanup` as a maintenance operation, so it streams in the console and reconciles the
    /// installed inventory like any other mutation, then previews again so the list shows what is left.
    func cleanUp() {
        guard canCleanUp else {
            return
        }
        let command = commandFactory.cleanupCommand(pruneAll: pruneAll)
        let operationID = BrewOperationID(maintenanceToken: "cleanup", displayCommand: command.displayCommand)
        cleanupErrorMessage = nil
        isCleaningUp = true
        cleanupTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                isCleaningUp = false
                cleanupTask = nil
            }
            do {
                try await commandCenter.perform(command, id: operationID)
            } catch is CancellationError {
                return
            } catch {
                let latestPhase = await commandCenter.phase(for: operationID)
                cleanupErrorMessage = if case let .failed(reason) = latestPhase {
                    BrewErrorCopy.message(for: reason)
                } else {
                    BrewErrorCopy.message(for: OperationFailure(catching: error))
                }
            }
            // A failed run can still have removed some of the list, so preview again either way.
            await load()
        }
    }

    private static func message(for error: any Error) -> String {
        BrewErrorCopy.message(
            for: error,
            fallback: String(
                localized: "Couldn't check what Homebrew can clean up.",
                bundle: #bundle,
                comment: "Cleanup tab, generic dry-run failure",
            ),
        )
    }
}
