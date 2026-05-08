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

    @Test func `observeRowUpdates ends on last phased stream emission`() async {
        let package = BrewPackage.fixture(name: "git", kind: .formula)
        let center = PhaseSequenceCommandCenter(phases: [.running(.upgradeFormula), .idle])
        let viewModel = InstalledListRowViewModel(package: package, brewCommandCenter: center)
        await viewModel.observeRowUpdates()
        #expect(viewModel.upgradeOperationPhase == .idle)
    }

    @Test func `update package flips row version presentation when outdated changes`() {
        let current = BrewPackage.fixture(
            name: "git",
            kind: .formula,
            description: "VCS",
            latestVersion: "2.47.1",
            installedVersions: ["2.46.0"],
            outdated: false,
        )
        let viewModel = InstalledListRowViewModel(
            package: current,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )

        #expect(!viewModel.showsUpdateAvailable)
        if case let .installed(label) = viewModel.versionPresentation {
            #expect(!label.isEmpty)
        } else {
            Issue.record("expected installed versionPresentation before update")
        }

        let outdated = BrewPackage.fixture(
            name: "git",
            kind: .formula,
            description: "VCS",
            latestVersion: "2.47.1",
            installedVersions: ["2.46.0"],
            outdated: true,
        )
        viewModel.update(package: outdated)

        #expect(viewModel.showsUpdateAvailable)
        if case .upgrade = viewModel.versionPresentation {
            ()
        } else {
            Issue.record("expected upgrade versionPresentation after update")
        }

        viewModel.update(package: outdated)
        #expect(viewModel.showsUpdateAvailable)
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

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream<(BrewOperationID, BrewOperationPhase)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }
}
