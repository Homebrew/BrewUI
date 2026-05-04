//
//  SerialBrewCommandCenter.swift
//  Brew
//

import Foundation

/// Runs async mutating work strictly one-at-a-time, including across `await` inside commands (serial policy).
private actor SerialBrewWorkQueue {
    func run(_ work: @Sendable @escaping () async throws -> Void) async rethrows {
        try await work()
    }
}

/// Default app implementation: serializes mutating `brew` subprocess work and exposes per-operation phase for UI.
actor SerialBrewCommandCenter: BrewCommandCenter {
    private let executionContext: BrewCommandExecutionContext
    private let workQueue = SerialBrewWorkQueue()

    private var trackedPhasesByID: [BrewOperationID: BrewOperationPhase] = [:]
    private var inflightByID: [BrewOperationID: Task<Void, Error>] = [:]

    init(executionContext: BrewCommandExecutionContext) {
        self.executionContext = executionContext
    }

    func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        trackedPhasesByID[id] ?? .idle
    }

    func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        trackedPhasesByID
    }

    func isActive(id: BrewOperationID) async -> Bool {
        if case .running = trackedPhasesByID[id] ?? .idle {
            return true
        }
        return false
    }

    func submit(
        id: BrewOperationID,
        command: any BrewMutatingCommand,
    ) async throws {
        if let existing = inflightByID[id] {
            try await existing.value
            return
        }

        let kind = command.operationKind
        let queue = workQueue
        let ctx = executionContext
        let task = Task<Void, Error> {
            try await queue.run {
                try await command.run(in: ctx)
            }
        }

        inflightByID[id] = task
        defer { inflightByID[id] = nil }

        trackedPhasesByID[id] = .running(kind)
        do {
            try await task.value
            trackedPhasesByID[id] = nil
        } catch {
            trackedPhasesByID[id] = .failed(reason: OperationFailure(catching: error))
            throw error
        }
    }
}
