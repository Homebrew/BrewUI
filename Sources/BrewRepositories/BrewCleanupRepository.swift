//
//  BrewCleanupRepository.swift
//  BrewRepositories
//

import BrewCLI
import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

/// Previews `brew cleanup` with `--dry-run`. The dry run changes nothing, so it runs directly rather than
/// through the command center: it stays out of the console and never queues behind a running mutation.
@Observable
@MainActor
public final class BrewCleanupRepository: CleanupRepository {
    public private(set) var state: LoadState<CleanupReport, any Error> = .loading
    public private(set) var refreshFailure: (any Error)?
    public private(set) var isRefreshing = false

    @ObservationIgnored private let commandRunner: any BrewCommandRunning
    @ObservationIgnored private let locator: any BrewExecutableLocating
    @ObservationIgnored private var inFlight: Task<Void, Never>?
    @ObservationIgnored private var inFlightPruneAll = false

    public init(commandRunner: any BrewCommandRunning, locator: any BrewExecutableLocating) {
        self.commandRunner = commandRunner
        self.locator = locator
    }

    /// Takes the context rather than building its own runner, so the composition root points every
    /// brew invocation at one place: production's isolated zsh runner, or a UI test's fake executable.
    public convenience init(executionContext: BrewCommandExecutionContext) {
        self.init(commandRunner: executionContext.commandRunner, locator: executionContext.locator)
    }

    public func load(pruneAll: Bool) async {
        // Loops because another waiter may start a run while this one waits; that run is checked again.
        while let running = inFlight {
            let sharesRun = inFlightPruneAll == pruneAll
            await running.value
            if inFlight == running {
                inFlight = nil
            }
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
        // A waiter may already have cleared it and started the next run.
        if inFlight == task {
            inFlight = nil
        }
    }

    private func fetch(pruneAll: Bool) async {
        let showsSameOption = state.value?.pruneAll == pruneAll
        if showsSameOption {
            isRefreshing = true
        } else {
            state = .loading
            // A failed refresh belongs to the report being dropped.
            refreshFailure = nil
        }
        defer { isRefreshing = false }

        do {
            let brew = try locator.findBrewExecutable()
            let output = try await commandRunner.run(executableURL: brew, arguments: Self.arguments(pruneAll: pruneAll))
            // Unlike `brew doctor`, a dry run exits 0 when it works.
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

    private static func arguments(pruneAll: Bool) -> [String] {
        ["cleanup", "--dry-run"] + (pruneAll ? ["--prune=all"] : [])
    }
}
