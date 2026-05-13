//
//  RecordingSerialBrewCommandCenter.swift
//  BrewTests
//

@testable import Brew
import Foundation

/// Test double wrapping ``SerialBrewCommandCenter``: appends `(id, kind)` for every ``BrewCommandCenter/submit``
/// invocation while preserving serial execution and duplicate-id coalescing.
actor RecordingSerialBrewCommandCenter: BrewCommandCenter {
    private let inner: SerialBrewCommandCenter
    private(set) var recordedSubmitEntries: [(id: BrewOperationID, kind: BrewOperationKind)] = []

    init(executionContext: BrewCommandExecutionContext) {
        inner = SerialBrewCommandCenter(executionContext: executionContext)
    }

    func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        await inner.phase(for: id)
    }

    func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        await inner.phaseByID()
    }

    func isActive(id: BrewOperationID) async -> Bool {
        await inner.isActive(id: id)
    }

    func phaseChanges(for id: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        await inner.phaseChanges(for: id)
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        await inner.allPhaseChanges()
    }

    func submit(
        id: BrewOperationID,
        command: any BrewMutatingCommand,
    ) async throws {
        recordedSubmitEntries.append((id, command.operationKind))
        try await inner.submit(id: id, command: command)
    }
}
