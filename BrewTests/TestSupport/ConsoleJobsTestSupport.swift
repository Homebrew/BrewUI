//
//  ConsoleJobsTestSupport.swift
//  BrewTests
//

@testable import Brew
import Foundation

/// Controllable ``BrewCommandCenter`` double for console tests: vends live `allPhaseChanges()` /
/// `allOutputChanges()` streams and lets a test push `(id, phase)` / `(id, line)` events through them,
/// so ``BrewCommandJobsRepository`` can be exercised via its real subscription path rather than an
/// internal seam. The per-id streams and `submit` are inert — the repository only consumes the
/// "all" streams.
actor ControllableJobsCommandCenter: BrewCommandCenter {
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

    func phase(for _: BrewOperationID) async -> BrewOperationPhase {
        .idle
    }

    func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    func isActive(id _: BrewOperationID) async -> Bool {
        false
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
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

    func outputChanges(for _: BrewOperationID) async -> AsyncStream<BrewCommandOutputLine> {
        AsyncStream<BrewCommandOutputLine>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
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

    func submit(
        id _: BrewOperationID,
        command _: any BrewMutatingCommand,
    ) async throws {}

    func emitPhase(id: BrewOperationID, phase: BrewOperationPhase) {
        for listener in allPhaseListeners {
            listener.continuation.yield((id, phase))
        }
    }

    func emitOutput(id: BrewOperationID, line: BrewCommandOutputLine) {
        for listener in allOutputListeners {
            listener.continuation.yield((id, line))
        }
    }

    func hasPhaseSubscriber() -> Bool {
        !allPhaseListeners.isEmpty
    }

    func hasOutputSubscriber() -> Bool {
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

/// Wires a ``ControllableJobsCommandCenter`` to a real ``BrewCommandJobsRepository`` (and a
/// ``ConsoleViewModel`` projecting it), then drives the repository by emitting through the center's
/// streams. Each `emit` settles the cooperative pipeline so the repository has processed the event
/// before the test asserts.
@MainActor
final class ConsoleJobsHarness {
    let center = ControllableJobsCommandCenter()
    let repository: BrewCommandJobsRepository
    let viewModel: ConsoleViewModel

    init() {
        repository = BrewCommandJobsRepository(commandCenter: center)
        viewModel = ConsoleViewModel(repository: repository)
    }

    /// Await the repository's init-time stream subscriptions before emitting, so buffered events reach it.
    func awaitReady() async {
        for _ in 0 ..< 200 {
            if await center.hasPhaseSubscriber(), await center.hasOutputSubscriber() {
                return
            }
            await Task.yield()
        }
    }

    func emit(id: BrewOperationID, phase: BrewOperationPhase) async {
        await center.emitPhase(id: id, phase: phase)
        await settle()
    }

    func emit(id: BrewOperationID, output line: BrewCommandOutputLine) async {
        await center.emitOutput(id: id, line: line)
        await settle()
    }

    private func settle() async {
        for _ in 0 ..< 50 {
            await Task.yield()
        }
    }
}
