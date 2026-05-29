//
//  BrewCommandJobsRepository.swift
//  Brew
//

import BrewCLI
import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

/// App-scoped projection of mutating brew operations the command center is running.
///
/// Long-lived `@Observable` injected into the SwiftUI environment so the console (and any other
/// surface that wants live operation state) renders from one cache fed by a single subscription
/// to ``BrewCommandCenter/allPhaseChanges()`` and ``BrewCommandCenter/allOutputChanges()``.
/// Never mutates the center — strictly downstream.
@Observable
@MainActor
public final class BrewCommandJobsRepository: CommandJobsObserving {
    public private(set) var jobs: [BrewOperationID: CommandJob] = [:]
    public private(set) var orderedIDs: [BrewOperationID] = []

    @ObservationIgnored private let commandCenter: any BrewCommandCenter
    @ObservationIgnored private var phaseObserverTask: Task<Void, Never>?
    @ObservationIgnored private var outputObserverTask: Task<Void, Never>?

    public init(commandCenter: any BrewCommandCenter) {
        self.commandCenter = commandCenter
        phaseObserverTask = Task { @MainActor [weak self] in
            await self?.observePhases()
        }
        outputObserverTask = Task { @MainActor [weak self] in
            await self?.observeOutput()
        }
    }

    isolated deinit {
        phaseObserverTask?.cancel()
        outputObserverTask?.cancel()
    }

    /// Drop a single job from the cache. In-flight operations keep running in the command center —
    /// this only removes the console-side projection, and any subsequent phase update for the dropped
    /// id is ignored by ``handlePhase(id:phase:)``.
    public func remove(id: BrewOperationID) {
        guard jobs[id] != nil else {
            return
        }
        jobs[id] = nil
        orderedIDs.removeAll { $0 == id }
    }

    /// Remove all terminal jobs from the cache. In-flight jobs are preserved.
    public func clearCompleted() {
        let preservedIDs = orderedIDs.filter { jobs[$0]?.isTerminal == false }
        let removedIDs = Set(orderedIDs).subtracting(preservedIDs)
        for id in removedIDs {
            jobs[id] = nil
        }
        orderedIDs = preservedIDs
    }

    /// Applies a phase transition from ``observePhases()`` to the cache.
    private func handlePhase(id: BrewOperationID, phase: BrewOperationPhase) {
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

    /// Appends a streamed output line from ``observeOutput()`` to the matching job.
    /// Output lines for unknown ids are dropped: a job materializes from its first
    /// ``BrewOperationPhase/running`` transition, which is always observed before any subprocess emits output.
    private func handleOutput(id: BrewOperationID, line: BrewCommandOutputLine) {
        guard let job = jobs[id] else {
            return
        }
        job.appendOutput(line)
    }

    private func observePhases() async {
        let stream = await commandCenter.allPhaseChanges()
        for await (id, phase) in stream {
            handlePhase(id: id, phase: phase)
        }
    }

    private func observeOutput() async {
        let stream = await commandCenter.allOutputChanges()
        for await (id, line) in stream {
            handleOutput(id: id, line: line)
        }
    }
}

@MainActor
public extension BrewCommandJobsRepository {
    /// Inert instance for the environment default and unscoped subtrees (no command-center bookkeeping).
    static func placeholder() -> BrewCommandJobsRepository {
        BrewCommandJobsRepository(commandCenter: NoopBrewCommandCenter.preview())
    }
}
