//
//  NoopBrewCommandCenter.swift
//  Brew
//

import Foundation

/// Pass-through center for previews and tests: runs commands immediately with no phase bookkeeping or queuing.
actor NoopBrewCommandCenter: BrewCommandCenter {
    private let executionContext: BrewCommandExecutionContext

    init(executionContext: BrewCommandExecutionContext) {
        self.executionContext = executionContext
    }

    /// Preconfigured noop center for SwiftUI previews (immediate execution, standard noop context).
    nonisolated static func preview() -> NoopBrewCommandCenter {
        NoopBrewCommandCenter(executionContext: .noopForTestingAndPreviews())
    }

    /// Preconfigured noop center for unit tests (same wiring as ``preview()``).
    nonisolated static func forTesting() -> NoopBrewCommandCenter {
        NoopBrewCommandCenter(executionContext: .noopForTestingAndPreviews())
    }

    func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        _ = id
        return .idle
    }

    func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    func isActive(id: BrewOperationID) async -> Bool {
        _ = id
        return false
    }

    func phaseChanges(for id: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        _ = id
        return AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
            continuation.yield(BrewOperationPhase.idle)
            continuation.finish()
        }
    }

    func submit(
        id: BrewOperationID,
        command: any BrewMutatingCommand,
    ) async throws {
        _ = id
        try await command.run(in: executionContext)
    }
}
