//
//  NoopBrewCommandCenter.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Pass-through center for previews and tests: runs commands immediately with no phase bookkeeping or queuing.
public actor NoopBrewCommandCenter: BrewCommandCenter {
    private let executionContext: BrewCommandExecutionContext

    public init(executionContext: BrewCommandExecutionContext) {
        self.executionContext = executionContext
    }

    /// Preconfigured noop center for SwiftUI previews (immediate execution, standard noop context).
    public nonisolated static func preview() -> NoopBrewCommandCenter {
        NoopBrewCommandCenter(executionContext: .noopForTestingAndPreviews())
    }

    /// Preconfigured noop center for unit tests (same wiring as ``preview()``).
    public nonisolated static func forTesting() -> NoopBrewCommandCenter {
        NoopBrewCommandCenter(executionContext: .noopForTestingAndPreviews())
    }

    public func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        _ = id
        return .idle
    }

    public func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    public func isActive(id: BrewOperationID) async -> Bool {
        _ = id
        return false
    }

    public func phaseChanges(for id: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        _ = id
        return AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
            continuation.yield(BrewOperationPhase.idle)
            continuation.finish()
        }
    }

    public func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream<(BrewOperationID, BrewOperationPhase)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    public func outputChanges(for id: BrewOperationID) async -> AsyncStream<BrewCommandOutputLine> {
        _ = id
        return AsyncStream<BrewCommandOutputLine>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    public func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream<(BrewOperationID, BrewCommandOutputLine)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    public func submit(
        id: BrewOperationID,
        command: any BrewMutatingCommand,
    ) async throws {
        _ = id
        try await command.run(in: executionContext)
    }
}
