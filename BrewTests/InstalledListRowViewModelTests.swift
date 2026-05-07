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
        let package = BrewPackage.fixture(name: "git", kind: .formula)
        let center = NoopBrewCommandCenter.forTesting()
        let viewModel = InstalledListRowViewModel(package: package, brewCommandCenter: center)
        #expect(viewModel.upgradeOperationPhase == .idle)

        await viewModel.observeRowUpdates()

        #expect(viewModel.upgradeOperationPhase == .idle)
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
