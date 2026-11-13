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

    /// Adds `--prune=all` to both the preview and the run, so what runs is what was reviewed.
    private(set) var pruneAll = false

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

    /// The prune toggle waits for the preview it would replace, so two dry runs never race.
    var isPruneAllToggleDisabled: Bool {
        presentation == .loading || isRefreshing
    }

    var refreshFailureMessage: String? {
        repository.refreshFailure.map(Self.message(for:))
    }

    /// The literal `brew cleanup` the button runs, shown so it can be copied to Terminal.
    var cleanupDisplayCommand: String {
        commandFactory.cleanupCommand(pruneAll: pruneAll).displayCommand
    }

    /// Clean Up waits for a fresh, non-empty preview made with the same option, so the run matches what
    /// the sheet shows (apart from unreferenced downloads, which the dry run never lists). A failed refresh leaves a stale report on screen, so it blocks too.
    var canCleanUp: Bool {
        presentation == .removable
            && !isRefreshing
            && repository.refreshFailure == nil
            && state.value?.pruneAll == pruneAll
    }

    /// With nothing to remove the sheet offers only Done, rather than Cancel beside a dead Clean Up.
    var showsDoneButton: Bool {
        presentation == .clean
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

    /// Names the formulae autoremove uninstalls, or `nil` when there are none.
    var uninstallMessage: String? {
        guard let report = state.value, !report.unneededFormulae.isEmpty else {
            return nil
        }
        let formulae = report.unneededFormulae.joined(separator: ", ")
        return String(
            localized: "This also uninstalls \(formulae).",
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

    /// Runs `brew cleanup` as a maintenance operation, so it streams in the console and reconciles the
    /// installed inventory like any other mutation. The sheet closes as soon as it starts, so the console
    /// reports the outcome, including Homebrew's stderr when it fails.
    @discardableResult
    func cleanUp() -> Task<Void, Never>? {
        guard canCleanUp else {
            return nil
        }
        let command = commandFactory.cleanupCommand(pruneAll: pruneAll)
        let operationID = BrewOperationID(maintenanceToken: "cleanup", displayCommand: command.displayCommand)
        let commandCenter = commandCenter
        return Task {
            try? await commandCenter.perform(command, id: operationID)
        }
    }

    private static func message(for error: any Error) -> String {
        BrewErrorCopy.message(
            for: error,
            fallback: String(
                localized: "Couldn't check what Homebrew can clean up.",
                bundle: #bundle,
                comment: "Clean Up sheet, generic dry-run failure",
            ),
        )
    }
}
