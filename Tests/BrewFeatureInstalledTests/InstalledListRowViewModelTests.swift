//
//  InstalledListRowViewModelTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import Foundation
import Testing

@MainActor
struct InstalledListRowViewModelTests {
    @Test func `installed version label prefers linked keg over first installed version`() {
        let package = InstalledBrewPackage.fixture(
            name: "git",
            installedVersions: ["1.9.0", "2.0.0"],
            linkedKeg: "2.0.0",
        )
        let viewModel = InstalledListRowViewModel(
            package: package,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.installedVersionLabel == "v2.0.0")
    }

    @Test func `installed version label falls back to first version when no linked keg`() {
        let package = InstalledBrewPackage.fixture(
            name: "git",
            installedVersions: ["1.9.0", "2.0.0"],
            linkedKeg: nil,
        )
        let viewModel = InstalledListRowViewModel(
            package: package,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.installedVersionLabel == "v1.9.0")
    }

    @Test func `name uses package display name`() {
        let package = InstalledBrewPackage.fixture(
            name: "visual-studio-code",
            displayName: "Visual Studio Code",
            kind: .cask,
        )
        let viewModel = InstalledListRowViewModel(
            package: package,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.name == "Visual Studio Code")
    }

    @Test func `observeRowUpdates applies first phase from noop center`() async {
        let package = InstalledBrewPackage.fixture(name: "git", kind: .formula)
        let center = NoopBrewCommandCenter.forTesting()
        let viewModel = InstalledListRowViewModel(package: package, brewCommandCenter: center)
        #expect(!viewModel.showsUpgradeBusy)

        await viewModel.observeRowUpdates()

        #expect(!viewModel.showsUpgradeBusy)
    }

    @Test func `observeRowUpdates ends on last phased stream emission`() async {
        var package = InstalledBrewPackage.fixture(name: "git", kind: .formula)
        package.outdated = true
        let center = PhaseSequenceCommandCenter(phases: [.running(.upgradeFormula), .idle])
        let viewModel = InstalledListRowViewModel(package: package, brewCommandCenter: center)
        await viewModel.observeRowUpdates()
        #expect(viewModel.showsUpgradeBusy)
        #expect(viewModel.showsOperationBusy)
        #expect(viewModel.rowAccessibilityLabel.contains("Upgrading"))
    }

    @Test func `observeRowUpdates latches uninstall busy after running to idle`() async {
        let package = InstalledBrewPackage.fixture(name: "git", kind: .formula)
        let center = PhaseSequenceCommandCenter(phases: [.running(.uninstallFormula), .idle])
        let viewModel = InstalledListRowViewModel(package: package, brewCommandCenter: center)
        await viewModel.observeRowUpdates()
        #expect(!viewModel.showsUpgradeBusy)
        #expect(viewModel.showsUninstallBusy)
        #expect(viewModel.showsOperationBusy)
        #expect(viewModel.rowAccessibilityLabel.contains("Uninstalling"))
    }

    @Test func `update package clears upgrade busy latch and operation busy`() async {
        var package = InstalledBrewPackage.fixture(name: "git", kind: .formula)
        package.outdated = true
        let center = PhaseSequenceCommandCenter(phases: [.running(.upgradeFormula), .idle])
        let viewModel = InstalledListRowViewModel(package: package, brewCommandCenter: center)
        await viewModel.observeRowUpdates()
        #expect(viewModel.showsUpgradeBusy)
        #expect(viewModel.showsOperationBusy)

        let refreshedPackage = InstalledBrewPackage.fixture(name: "git", kind: .formula)
        viewModel.update(package: refreshedPackage)

        #expect(!viewModel.showsUpgradeBusy)
        #expect(!viewModel.showsUninstallBusy)
        #expect(!viewModel.showsOperationBusy)
        #expect(!viewModel.rowAccessibilityLabel.contains("Upgrading"))
    }

    @Test func `update package clears uninstall busy latch and operation busy`() async {
        let package = InstalledBrewPackage.fixture(name: "git", kind: .formula)
        let center = PhaseSequenceCommandCenter(phases: [.running(.uninstallFormula), .idle])
        let viewModel = InstalledListRowViewModel(package: package, brewCommandCenter: center)
        await viewModel.observeRowUpdates()
        #expect(viewModel.showsUninstallBusy)
        #expect(viewModel.showsOperationBusy)

        let refreshedPackage = InstalledBrewPackage.fixture(name: "git", kind: .formula, description: "Updated")
        viewModel.update(package: refreshedPackage)

        #expect(!viewModel.showsUpgradeBusy)
        #expect(!viewModel.showsUninstallBusy)
        #expect(!viewModel.showsOperationBusy)
        #expect(!viewModel.rowAccessibilityLabel.contains("Uninstalling"))
    }

    @Test func `update package flips row version presentation when outdated changes`() {
        let current = InstalledBrewPackage.fixture(
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

        #expect(!viewModel.showsUpgradeAvailable)
        if case let .installed(label) = viewModel.versionPresentation {
            #expect(!label.isEmpty)
        } else {
            Issue.record("expected installed versionPresentation before update")
        }

        let outdated = InstalledBrewPackage.fixture(
            name: "git",
            kind: .formula,
            description: "VCS",
            latestVersion: "2.47.1",
            installedVersions: ["2.46.0"],
            outdated: true,
        )
        viewModel.update(package: outdated)

        #expect(viewModel.showsUpgradeAvailable)
        if case .upgrade = viewModel.versionPresentation {
            ()
        } else {
            Issue.record("expected upgrade versionPresentation after update")
        }

        viewModel.update(package: outdated)
        #expect(viewModel.showsUpgradeAvailable)
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

    func outputChanges(for _: BrewOperationID) async -> AsyncStream<BrewCommandOutputLine> {
        AsyncStream<BrewCommandOutputLine>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream<(BrewOperationID, BrewCommandOutputLine)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }
}
