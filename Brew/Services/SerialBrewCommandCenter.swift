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

private struct PhaseStreamListener {
    let token: UUID
    let continuation: AsyncStream<BrewOperationPhase>.Continuation
}

/// Default app implementation: serializes mutating `brew` subprocess work and exposes per-operation phase for UI.
actor SerialBrewCommandCenter: BrewCommandCenter {
    private let executionContext: BrewCommandExecutionContext
    private let workQueue = SerialBrewWorkQueue()

    private var trackedPhasesByID: [BrewOperationID: BrewOperationPhase] = [:]
    private var inflightByID: [BrewOperationID: Task<Void, Error>] = [:]
    private var phaseListenersByID: [BrewOperationID: [PhaseStreamListener]] = [:]

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

    func phaseChanges(for id: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
            let token = UUID()
            continuation.onTermination = { @Sendable (_: AsyncStream<BrewOperationPhase>.Continuation.Termination) in
                Task {
                    await self.removePhaseListener(id: id, token: token)
                }
            }
            registerPhaseListener(id: id, token: token, continuation: continuation)
        }
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
        notifyPhaseListeners(for: id)
        do {
            try await task.value
            trackedPhasesByID[id] = nil
            notifyPhaseListeners(for: id)
        } catch {
            trackedPhasesByID[id] = .failed(reason: OperationFailure(catching: error))
            notifyPhaseListeners(for: id)
            throw error
        }
    }

    private func registerPhaseListener(
        id: BrewOperationID,
        token: UUID,
        continuation: AsyncStream<BrewOperationPhase>.Continuation,
    ) {
        let listener = PhaseStreamListener(token: token, continuation: continuation)
        phaseListenersByID[id, default: []].append(listener)
        let snapshot = trackedPhasesByID[id] ?? .idle
        continuation.yield(snapshot)
    }

    private func removePhaseListener(id: BrewOperationID, token: UUID) {
        guard var listeners = phaseListenersByID[id] else {
            return
        }
        listeners.removeAll { $0.token == token }
        if listeners.isEmpty {
            phaseListenersByID[id] = nil
        } else {
            phaseListenersByID[id] = listeners
        }
    }

    private func notifyPhaseListeners(for id: BrewOperationID) {
        let phase = trackedPhasesByID[id] ?? .idle
        guard let listeners = phaseListenersByID[id] else {
            return
        }
        for listener in listeners {
            listener.continuation.yield(phase)
        }
    }
}
