//
//  SerialBrewCommandCenter.swift
//  BrewCLI
//

import BrewCore
import Foundation

private typealias AllPhaseStreamTermination =
    AsyncStream<(BrewOperationID, BrewOperationPhase)>.Continuation.Termination

private typealias OutputStreamTermination =
    AsyncStream<BrewCommandOutputLine>.Continuation.Termination

private typealias AllOutputStreamTermination =
    AsyncStream<(BrewOperationID, BrewCommandOutputLine)>.Continuation.Termination

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

private struct AllPhaseStreamListener {
    let token: UUID
    let continuation: AsyncStream<(BrewOperationID, BrewOperationPhase)>.Continuation
}

private struct OutputStreamListener {
    let token: UUID
    let continuation: AsyncStream<BrewCommandOutputLine>.Continuation
}

private struct AllOutputStreamListener {
    let token: UUID
    let continuation: AsyncStream<(BrewOperationID, BrewCommandOutputLine)>.Continuation
}

/// Default app implementation: serializes mutating `brew` subprocess work and exposes per-operation phase for UI.
public actor SerialBrewCommandCenter: BrewCommandCenter {
    private let executionContext: BrewCommandExecutionContext
    private let workQueue = SerialBrewWorkQueue()

    private var trackedPhasesByID: [BrewOperationID: BrewOperationPhase] = [:]
    private var inflightByID: [BrewOperationID: Task<Void, Error>] = [:]
    private var phaseListenersByID: [BrewOperationID: [PhaseStreamListener]] = [:]
    private var allPhaseListeners: [AllPhaseStreamListener] = []
    private var outputListenersByID: [BrewOperationID: [OutputStreamListener]] = [:]
    private var allOutputListeners: [AllOutputStreamListener] = []

    public init(executionContext: BrewCommandExecutionContext) {
        self.executionContext = executionContext
    }

    public func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        trackedPhasesByID[id] ?? .idle
    }

    public func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        trackedPhasesByID
    }

    public func isActive(id: BrewOperationID) async -> Bool {
        if case .running = trackedPhasesByID[id] ?? .idle {
            return true
        }
        return false
    }

    public func phaseChanges(for id: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
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

    public func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream<(BrewOperationID, BrewOperationPhase)>(bufferingPolicy: .unbounded) { continuation in
            let token = UUID()
            continuation.onTermination = { @Sendable (_: AllPhaseStreamTermination) in
                Task {
                    await self.removeAllPhaseListener(token: token)
                }
            }
            registerAllPhaseListener(token: token, continuation: continuation)
        }
    }

    public func outputChanges(for id: BrewOperationID) async -> AsyncStream<BrewCommandOutputLine> {
        AsyncStream<BrewCommandOutputLine>(bufferingPolicy: .unbounded) { continuation in
            let token = UUID()
            continuation.onTermination = { @Sendable (_: OutputStreamTermination) in
                Task {
                    await self.removeOutputListener(id: id, token: token)
                }
            }
            registerOutputListener(id: id, token: token, continuation: continuation)
        }
    }

    public func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream<(BrewOperationID, BrewCommandOutputLine)>(bufferingPolicy: .unbounded) { continuation in
            let token = UUID()
            continuation.onTermination = { @Sendable (_: AllOutputStreamTermination) in
                Task {
                    await self.removeAllOutputListener(token: token)
                }
            }
            registerAllOutputListener(token: token, continuation: continuation)
        }
    }

    public func submit(
        id: BrewOperationID,
        command: any BrewMutatingCommand,
    ) async throws {
        if let existing = inflightByID[id] {
            try await existing.value
            return
        }

        let kind = command.operationKind
        let queue = workQueue

        // An internal AsyncStream serves as a thread-safe, FIFO-ordered buffer between the subprocess reader threads
        // (which call `sink` synchronously) and the actor's listener-broadcast (which requires actor isolation).
        // Yielding into a continuation is Sendable + thread-safe; a single drain Task pulls in order onto the actor.
        let (lineStream, lineContinuation) = AsyncStream<BrewCommandOutputLine>.makeStream(
            bufferingPolicy: .unbounded,
        )

        // Attach the console stream to a per-operation copy of the context; commands forward it into the runner,
        // which streams lines here and forces colour. Read commands run with the base (console-less) context.
        var operationContext = executionContext
        operationContext.console = ConsoleOutputStream { line in
            lineContinuation.yield(line)
        }
        let ctx = operationContext

        let drainTask = Task { [weak self] in
            for await line in lineStream {
                await self?.notifyOutputListeners(id: id, line: line)
            }
        }

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
            lineContinuation.finish()
            await drainTask.value
            trackedPhasesByID[id] = nil
            notifyPhaseListeners(for: id)
        } catch {
            lineContinuation.finish()
            await drainTask.value
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

    private func registerAllPhaseListener(
        token: UUID,
        continuation: AsyncStream<(BrewOperationID, BrewOperationPhase)>.Continuation,
    ) {
        let listener = AllPhaseStreamListener(token: token, continuation: continuation)
        allPhaseListeners.append(listener)
    }

    private func removeAllPhaseListener(token: UUID) {
        allPhaseListeners.removeAll { $0.token == token }
    }

    private func registerOutputListener(
        id: BrewOperationID,
        token: UUID,
        continuation: AsyncStream<BrewCommandOutputLine>.Continuation,
    ) {
        let listener = OutputStreamListener(token: token, continuation: continuation)
        outputListenersByID[id, default: []].append(listener)
    }

    private func removeOutputListener(id: BrewOperationID, token: UUID) {
        guard var listeners = outputListenersByID[id] else {
            return
        }
        listeners.removeAll { $0.token == token }
        if listeners.isEmpty {
            outputListenersByID[id] = nil
        } else {
            outputListenersByID[id] = listeners
        }
    }

    private func registerAllOutputListener(
        token: UUID,
        continuation: AsyncStream<(BrewOperationID, BrewCommandOutputLine)>.Continuation,
    ) {
        let listener = AllOutputStreamListener(token: token, continuation: continuation)
        allOutputListeners.append(listener)
    }

    private func removeAllOutputListener(token: UUID) {
        allOutputListeners.removeAll { $0.token == token }
    }

    private func notifyPhaseListeners(for id: BrewOperationID) {
        let phase = trackedPhasesByID[id] ?? .idle
        if let listeners = phaseListenersByID[id] {
            for listener in listeners {
                listener.continuation.yield(phase)
            }
        }
        for listener in allPhaseListeners {
            listener.continuation.yield((id, phase))
        }
    }

    private func notifyOutputListeners(id: BrewOperationID, line: BrewCommandOutputLine) {
        if let listeners = outputListenersByID[id] {
            for listener in listeners {
                listener.continuation.yield(line)
            }
        }
        for listener in allOutputListeners {
            listener.continuation.yield((id, line))
        }
    }
}
