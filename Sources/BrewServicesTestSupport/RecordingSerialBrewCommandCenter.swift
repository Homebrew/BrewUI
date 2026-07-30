//
//  RecordingSerialBrewCommandCenter.swift
//  BrewServicesTestSupport
//

import BrewCLI
import BrewCore
import Foundation

/// Test double wrapping ``SerialBrewCommandCenter``: appends `(id, kind)` for every ``BrewCommandCenter/submit``
/// invocation while preserving serial execution and duplicate-id coalescing.
public actor RecordingSerialBrewCommandCenter: BrewCommandCenter {
    private let inner: SerialBrewCommandCenter
    public private(set) var recordedSubmitEntries: [(id: BrewOperationID, kind: BrewOperationKind)] = []

    public init(executionContext: BrewCommandExecutionContext) {
        inner = SerialBrewCommandCenter(executionContext: executionContext)
    }

    public func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        await inner.phase(for: id)
    }

    public func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        await inner.phaseByID()
    }

    public func isActive(id: BrewOperationID) async -> Bool {
        await inner.isActive(id: id)
    }

    public func phaseChanges(for id: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        await inner.phaseChanges(for: id)
    }

    public func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        await inner.allPhaseChanges()
    }

    public func outputChanges(for id: BrewOperationID) async -> AsyncStream<BrewCommandOutputLine> {
        await inner.outputChanges(for: id)
    }

    public func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        await inner.allOutputChanges()
    }

    @discardableResult
    public func run(_ command: BrewCommand, id: BrewOperationID) async throws -> CommandOutput {
        recordedSubmitEntries.append((id, command.operationKind))
        return try await inner.run(command, id: id)
    }

    public func runExpectingSuccess(_ command: BrewCommand, id: BrewOperationID) async throws {
        recordedSubmitEntries.append((id, command.operationKind))
        try await inner.runExpectingSuccess(command, id: id)
    }
}
