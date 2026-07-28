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

    public func phaseChanges(for id: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        await inner.phaseChanges(for: id)
    }

    public func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        await inner.allPhaseChanges()
    }

    public func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        await inner.allOutputChanges()
    }

    public func submit(
        id: BrewOperationID,
        command: any BrewMutatingCommand,
    ) async throws {
        recordedSubmitEntries.append((id, command.operationKind))
        try await inner.submit(id: id, command: command)
    }
}
