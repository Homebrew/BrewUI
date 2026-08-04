//
//  ControllableJobsCommandCenter.swift
//  BrewServicesTestSupport
//

import BrewCore
import Foundation

/// Controllable ``BrewCommandCenter`` double for console tests: vends live `allPhaseChanges()` /
/// `allOutputChanges()` streams and lets a test push `(id, phase)` / `(id, line)` events through them,
/// so ``BrewCommandJobsRepository`` can be exercised via its real subscription path rather than an
/// internal seam. The per-id streams and `submit` are inert — the repository only consumes the
/// "all" streams.
public actor ControllableJobsCommandCenter: BrewCommandCenter {
    private typealias AllPhaseTermination =
        AsyncStream<(BrewOperationID, BrewOperationPhase)>.Continuation.Termination
    private typealias AllOutputTermination =
        AsyncStream<(BrewOperationID, BrewCommandOutputLine)>.Continuation.Termination

    private struct AllPhaseStreamListener {
        let token: UUID
        let continuation: AsyncStream<(BrewOperationID, BrewOperationPhase)>.Continuation
    }

    private struct AllOutputStreamListener {
        let token: UUID
        let continuation: AsyncStream<(BrewOperationID, BrewCommandOutputLine)>.Continuation
    }

    private var allPhaseListeners: [AllPhaseStreamListener] = []
    private var allOutputListeners: [AllOutputStreamListener] = []
    private var trackedPhasesByID: [BrewOperationID: BrewOperationPhase] = [:]

    public init() {}

    public func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        trackedPhasesByID[id] ?? .idle
    }

    public func runningPhases() async -> [BrewOperationID: BrewOperationPhase] {
        trackedPhasesByID
    }

    public func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    public func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream<(BrewOperationID, BrewOperationPhase)>(bufferingPolicy: .unbounded) { continuation in
            let token = UUID()
            continuation.onTermination = { @Sendable (_: AllPhaseTermination) in
                Task {
                    await self.removeAllPhaseListener(token: token)
                }
            }
            registerAllPhaseListener(token: token, continuation: continuation)
        }
    }

    public func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream<(BrewOperationID, BrewCommandOutputLine)>(bufferingPolicy: .unbounded) { continuation in
            let token = UUID()
            continuation.onTermination = { @Sendable (_: AllOutputTermination) in
                Task {
                    await self.removeAllOutputListener(token: token)
                }
            }
            registerAllOutputListener(token: token, continuation: continuation)
        }
    }

    @discardableResult
    public func capture(_: BrewCommand, id _: BrewOperationID) async throws -> CommandOutput {
        // Inert double: the repository under test only consumes the "all" streams, never this return.
        CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }

    public func perform(_: BrewCommand, id _: BrewOperationID) async throws {}

    public func emitPhase(id: BrewOperationID, phase: BrewOperationPhase) {
        // Mirror the real center's bookkeeping so runningPhases()/phase(for:) reflect what was emitted.
        if case .idle = phase {
            trackedPhasesByID[id] = nil
        } else {
            trackedPhasesByID[id] = phase
        }
        for listener in allPhaseListeners {
            listener.continuation.yield((id, phase))
        }
    }

    public func emitOutput(id: BrewOperationID, line: BrewCommandOutputLine) {
        for listener in allOutputListeners {
            listener.continuation.yield((id, line))
        }
    }

    public func hasPhaseSubscriber() -> Bool {
        !allPhaseListeners.isEmpty
    }

    public func hasOutputSubscriber() -> Bool {
        !allOutputListeners.isEmpty
    }

    private func registerAllPhaseListener(
        token: UUID,
        continuation: AsyncStream<(BrewOperationID, BrewOperationPhase)>.Continuation,
    ) {
        allPhaseListeners.append(AllPhaseStreamListener(token: token, continuation: continuation))
    }

    private func removeAllPhaseListener(token: UUID) {
        allPhaseListeners.removeAll { $0.token == token }
    }

    private func registerAllOutputListener(
        token: UUID,
        continuation: AsyncStream<(BrewOperationID, BrewCommandOutputLine)>.Continuation,
    ) {
        allOutputListeners.append(AllOutputStreamListener(token: token, continuation: continuation))
    }

    private func removeAllOutputListener(token: UUID) {
        allOutputListeners.removeAll { $0.token == token }
    }
}
