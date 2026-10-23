//
//  BrewCleanupRepository.swift
//  BrewRepositories
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

/// Previews `brew cleanup` with `--dry-run`. The run goes through ``BrewCommandCenter`` so the user sees
/// exactly what Homebrew printed in the console, and the parsed report is only a structured view of it.
@Observable
@MainActor
public final class BrewCleanupRepository: CleanupRepository {
    public private(set) var state: LoadState<CleanupReport, any Error> = .loading
    public private(set) var refreshFailure: (any Error)?
    public private(set) var isRefreshing = false

    @ObservationIgnored private let commandCenter: any BrewCommandCenter
    @ObservationIgnored private var inFlight: Task<Void, Never>?
    @ObservationIgnored private var inFlightPruneAll = false

    public init(commandCenter: any BrewCommandCenter) {
        self.commandCenter = commandCenter
    }

    public func load(pruneAll: Bool) async {
        if let inFlight {
            let sharesRun = inFlightPruneAll == pruneAll
            await inFlight.value
            if sharesRun {
                return
            }
        }
        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await fetch(pruneAll: pruneAll)
        }
        inFlight = task
        inFlightPruneAll = pruneAll
        await task.value
        inFlight = nil
    }

    private func fetch(pruneAll: Bool) async {
        let showsSameOption = state.value?.pruneAll == pruneAll
        if showsSameOption {
            isRefreshing = true
        } else {
            state = .loading
        }
        defer { isRefreshing = false }

        let command = BrewCommands.cleanupPreview(pruneAll: pruneAll)
        // One token for both options, so the console reuses a single preview job rather than adding one per visit.
        let id = BrewOperationID(maintenanceToken: "cleanupPreview", displayCommand: command.displayCommand)
        do {
            let output = try await commandCenter.capture(command, id: id)
            // Capture leaves exit codes to the caller; unlike `brew doctor`, a dry run exits 0 when it works.
            guard output.terminationStatus == 0 else {
                throw BrewCommandError.failed(
                    exitCode: output.terminationStatus,
                    stderr: ANSIParser.plainText(output.standardError),
                )
            }
            state = .loaded(CleanupOutputParser.parse(output.standardOutput, pruneAll: pruneAll))
            refreshFailure = nil
        } catch is CancellationError {
            return
        } catch {
            if showsSameOption {
                refreshFailure = error
            } else {
                state = .failed(error)
            }
        }
    }
}
