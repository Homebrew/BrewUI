//
//  BrewCommandJobsRepository.swift
//  Brew
//

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
    public private(set) var jobs: [CommandJobID: CommandJob] = [:]
    public private(set) var orderedIDs: [CommandJobID] = []

    /// Routing map: the console job (tab) that live phase/output updates for a given ``BrewOperationID``
    /// belong to. The command center reuses a ``BrewOperationID`` across successive operations on the same
    /// package, so this indirection is what lets us route updates without conflating distinct runs.
    @ObservationIgnored private var liveJobByOperationID: [BrewOperationID: CommandJobID] = [:]

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
    public func remove(id: CommandJobID) {
        guard jobs[id] != nil else {
            return
        }
        jobs[id] = nil
        orderedIDs.removeAll { $0 == id }
        // Drop any live routing that pointed at this tab so a later run for that operation starts fresh.
        liveJobByOperationID = liveJobByOperationID.filter { $0.value != id }
    }

    /// Remove all terminal jobs from the cache. In-flight jobs are preserved.
    public func clearCompleted() {
        let preservedIDs = orderedIDs.filter { jobs[$0]?.isTerminal == false }
        let removedIDs = Set(orderedIDs).subtracting(preservedIDs)
        for id in removedIDs {
            jobs[id] = nil
        }
        orderedIDs = preservedIDs
        liveJobByOperationID = liveJobByOperationID.filter { !removedIDs.contains($0.value) }
    }

    /// Applies a phase transition from ``observePhases()`` to the cache.
    private func handlePhase(id operationID: BrewOperationID, phase: BrewOperationPhase) {
        if let liveID = liveJobByOperationID[operationID], let existing = jobs[liveID] {
            existing.updatePhase(phase)
            return
        }

        // Only materialize new jobs from a `.running` transition — `.idle` for an unknown id
        // is the AsyncStream initial-replay artifact and carries no operation kind to derive a command from.
        guard case let .running(kind) = phase else {
            return
        }
        let job = CommandJob.materialize(id: operationID, kind: kind, phase: phase)
        jobs[job.id] = job
        orderedIDs.append(job.id)
        liveJobByOperationID[operationID] = job.id
    }

    /// Appends a streamed output line from ``observeOutput()`` to the job currently live for that operation.
    /// Output lines for unknown ids are dropped: a job materializes from its first
    /// ``BrewOperationPhase/running`` transition, which is always observed before any subprocess emits output.
    private func handleOutput(id operationID: BrewOperationID, line: BrewCommandOutputLine) {
        guard let liveID = liveJobByOperationID[operationID], let job = jobs[liveID] else {
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
