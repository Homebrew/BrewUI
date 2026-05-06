//
//  InstalledListRowViewModelTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

@MainActor
struct InstalledListRowViewModelTests {
    @Test func `observeRowUpdates applies first phase from noop center`() async {
        let row = InstalledPackageRow(
            name: "git",
            kind: .formula,
            description: "",
            installedVersion: "v1",
        )
        let center = NoopBrewCommandCenter.forTesting()
        let viewModel = InstalledListRowViewModel(row: row)
        #expect(viewModel.upgradeOperationPhase == .idle)

        await viewModel.observeRowUpdates(for: row, using: center)

        #expect(viewModel.upgradeOperationPhase == .idle)
    }

    @Test func `observeRowUpdates refreshes row after running transitions back to idle`() async {
        let initialRow = InstalledPackageRow(
            name: "git",
            kind: .formula,
            description: "",
            installedVersion: "v1.0.0",
            updateVersion: "v2.0.0",
        )
        let refreshedRow = InstalledPackageRow(
            name: "git",
            kind: .formula,
            description: "",
            installedVersion: "v2.0.0",
            updateVersion: nil,
        )
        let center = PhaseSequenceCommandCenter(phases: [.running(.upgradeFormula), .idle])
        let callbackSpy = RowUpdatedCallbackSpy()
        let viewModel = InstalledListRowViewModel(
            row: initialRow,
            refreshRow: { row in
                _ = row
                return refreshedRow
            },
            onRowUpdated: { row in
                callbackSpy.record(row: row)
            },
        )

        await viewModel.observeRowUpdates(for: initialRow, using: center)

        #expect(viewModel.row.installedVersion == "v2.0.0")
        #expect(viewModel.row.updateVersion == nil)
        #expect(callbackSpy.rows.count == 1)
        #expect(callbackSpy.rows.first?.installedVersion == "v2.0.0")
    }
}

private actor PhaseSequenceCommandCenter: BrewCommandCenter {
    private let phases: [BrewOperationPhase]

    init(phases: [BrewOperationPhase]) {
        self.phases = phases
    }

    func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        _ = id
        return phases.last ?? .idle
    }

    func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    func isActive(id: BrewOperationID) async -> Bool {
        _ = id
        return phases.contains { phase in
            if case .running = phase {
                return true
            }
            return false
        }
    }

    func submit(id: BrewOperationID, command: any BrewMutatingCommand) async throws {
        _ = id
        _ = command
    }

    func phaseChanges(for id: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        _ = id
        return AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
            for phase in phases {
                continuation.yield(phase)
            }
            continuation.finish()
        }
    }
}

@MainActor
private final class RowUpdatedCallbackSpy {
    private(set) var rows: [InstalledPackageRow] = []

    func record(row: InstalledPackageRow) {
        rows.append(row)
    }
}
