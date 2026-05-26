//
//  JobRegistry.swift
//  Brew
//

import Foundation

/// SwiftUI-side projection of command-center operations for the console UI.
///
/// Subscribes to ``BrewCommandCenter/allPhaseChanges()`` (and later, output streams) and
/// caches per-job state for views to read. Never mutates the center — strictly downstream.
@Observable
@MainActor
final class JobRegistry {
    private(set) var jobs: [BrewOperationID: CommandJob] = [:]
    private(set) var orderedIDs: [BrewOperationID] = []
    var selectedID: BrewOperationID?

    private var observationTasks: [Task<Void, Never>] = []
    private var isObserving = false

    init() {}

    /// Most recently started job that has not yet reached terminal state (failed or finished).
    var activeJob: CommandJob? {
        for id in orderedIDs.reversed() {
            if let job = jobs[id], !job.isTerminal {
                return job
            }
        }
        return nil
    }

    /// Currently focused job for the expanded console body — explicit selection, else active, else most recent.
    var selectedJob: CommandJob? {
        if let id = selectedID, let job = jobs[id] {
            return job
        }
        if let active = activeJob {
            return active
        }
        return orderedIDs.last.flatMap { jobs[$0] }
    }

    /// Begin observing the given command center. Idempotent — repeated calls are no-ops.
    /// Spawned tasks live for the registry's lifetime; this is wired once at app launch.
    func startObserving(_ center: any BrewCommandCenter) {
        guard !isObserving else {
            return
        }
        isObserving = true

        let phaseTask = Task { [weak self] in
            let stream = await center.allPhaseChanges()
            for await (id, phase) in stream {
                guard let self else {
                    return
                }
                handlePhase(id: id, phase: phase)
            }
        }
        observationTasks.append(phaseTask)
    }

    /// Jobs targeting a specific package, oldest first.
    func jobs(for packageName: String) -> [CommandJob] {
        orderedIDs.compactMap { jobs[$0] }.filter {
            if case let .package(name) = $0.scope {
                return name == packageName
            }
            return false
        }
    }

    /// Remove all terminal jobs from the registry. In-flight jobs are preserved.
    func clearCompleted() {
        let preservedIDs = orderedIDs.filter { jobs[$0]?.isTerminal == false }
        let removedIDs = Set(orderedIDs).subtracting(preservedIDs)
        for id in removedIDs {
            jobs[id] = nil
        }
        orderedIDs = preservedIDs
        if let selected = selectedID, removedIDs.contains(selected) {
            selectedID = nil
        }
    }

    /// Test-and-internal seam — exercised from ``startObserving(_:)`` and unit tests.
    func handlePhase(id: BrewOperationID, phase: BrewOperationPhase) {
        if let existing = jobs[id] {
            existing.updatePhase(phase)
            return
        }

        // Only materialize new jobs from a `.running` transition — `.idle` for an unknown id
        // is the AsyncStream initial-replay artifact and carries no operation kind to derive a command from.
        guard case let .running(kind) = phase else {
            return
        }
        let job = CommandJob.materialize(id: id, kind: kind, phase: phase)
        jobs[id] = job
        orderedIDs.append(id)
    }
}
