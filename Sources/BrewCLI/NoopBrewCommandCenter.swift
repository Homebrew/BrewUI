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

    /// Preconfigured noop center for unit tests (immediate execution, standard noop context).
    public static func forTesting() -> NoopBrewCommandCenter {
        NoopBrewCommandCenter(executionContext: .noopForTestingAndPreviews())
    }

    public func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        _ = id
        return .idle
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

    public func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream<(BrewOperationID, BrewCommandOutputLine)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    @discardableResult
    public func capture(_ command: BrewCommand, id: BrewOperationID) async throws -> CommandOutput {
        _ = id
        let brew = try executionContext.brewExecutableURL()
        return try await executionContext.commandRunner.run(executableURL: brew, arguments: command.arguments)
    }

    public func perform(_ command: BrewCommand, id: BrewOperationID) async throws {
        _ = try await capture(command, id: id)
    }
}
