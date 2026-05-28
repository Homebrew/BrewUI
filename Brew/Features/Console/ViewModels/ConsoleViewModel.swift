//
//  ConsoleViewModel.swift
//  Brew
//

import Foundation
import Observation

/// Screen-local state and projections for the console feature.
///
/// Projects the shared ``CommandJobsObserving`` repository's jobs through screen-local selection,
/// and exposes the intent methods the console views call. The repository is the single source of
/// truth for cached operation state; this view model owns selection plus presentation-shaped
/// derivations that views shouldn't compute inline.
@Observable
@MainActor
final class ConsoleViewModel {
    @ObservationIgnored private let repository: any CommandJobsObserving

    var selectedID: BrewOperationID?

    init(repository: any CommandJobsObserving) {
        self.repository = repository
    }

    var orderedJobs: [CommandJob] {
        repository.orderedIDs.compactMap { repository.jobs[$0] }
    }

    /// Most recently started job that has not yet reached terminal state.
    var activeJob: CommandJob? {
        for id in repository.orderedIDs.reversed() {
            if let job = repository.jobs[id], !job.isTerminal {
                return job
            }
        }
        return nil
    }

    /// Currently focused job for the expanded console body — explicit selection, else active, else most recent.
    var selectedJob: CommandJob? {
        if let id = selectedID, let job = repository.jobs[id] {
            return job
        }
        if let active = activeJob {
            return active
        }
        return repository.orderedIDs.last.flatMap { repository.jobs[$0] }
    }

    var statusPresentation: ConsoleStatusPresentation {
        if let active = activeJob {
            return ConsoleStatusPresentation(
                dotState: active.dotState,
                summary: .running(command: active.command, shortLabel: active.phase.shortLabel),
                isRunning: true,
            )
        }
        if let lastID = repository.orderedIDs.last,
           let last = repository.jobs[lastID],
           last.isTerminal
        {
            return ConsoleStatusPresentation(
                dotState: last.dotState,
                summary: .completed(
                    command: last.command,
                    succeeded: last.succeeded,
                    exitCode: last.exitCode ?? -1,
                ),
                isRunning: false,
            )
        }
        return ConsoleStatusPresentation(dotState: .idle, summary: .idle, isRunning: false)
    }

    func select(id: BrewOperationID) {
        selectedID = id
    }

    func dismiss(id: BrewOperationID) {
        if selectedID == id {
            selectedID = nil
        }
        repository.remove(id: id)
    }

    func clearCompleted() {
        if let selected = selectedID, repository.jobs[selected]?.isTerminal == true {
            selectedID = nil
        }
        repository.clearCompleted()
    }
}
