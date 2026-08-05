//
//  InstalledDetailMutationParityTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
@testable import BrewRepositoryInterfaces
import Testing

@MainActor
struct InstalledDetailMutationParityTests {
    @Test func `uninstall failure maps launch failure to underlying message`() async {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: ThrowingSubmitCommandCenter(
                error: BrewCommandError.launchFailed(underlying: "spawn failed"),
            ),
        )

        await withInstalledDetailPhaseObservation(on: viewModel) {
            viewModel.uninstallSelectedPackage()
            await waitForUninstallError(on: viewModel)
            #expect(viewModel.uninstallErrorMessage == "spawn failed")
        }
    }

    @Test func `uninstall failure with empty stderr uses generic brew failure message`() async {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: ThrowingSubmitCommandCenter(
                error: BrewCommandError.failed(exitCode: 1, stderr: " \n"),
            ),
        )

        await withInstalledDetailPhaseObservation(on: viewModel) {
            viewModel.uninstallSelectedPackage()
            await waitForUninstallError(on: viewModel)
            #expect(viewModel.uninstallErrorMessage == "Homebrew command failed.")
        }
    }

    @Test func `isMutatingPackage is true while upgrade is running`() async {
        let center = RunningSubmitCountingCommandCenter()
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: center,
        )

        viewModel.upgradeSelectedPackage()
        let observer = Task { await viewModel.observeRowUpdates() }
        defer { observer.cancel() }

        await waitForUpgrading(on: viewModel)
        #expect(viewModel.isMutatingPackage)
    }

    @Test func `isMutatingPackage is true while uninstall is running`() async {
        let center = RunningSubmitCountingCommandCenter(phase: .running(.uninstallFormula))
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: center,
        )

        viewModel.uninstallSelectedPackage()
        let observer = Task { await viewModel.observeRowUpdates() }
        defer { observer.cancel() }

        await waitForUninstalling(on: viewModel)
        #expect(viewModel.isMutatingPackage)
    }

    @Test func `isMutatingPackage clears after uninstall completes`() async {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )

        await withInstalledDetailPhaseObservation(on: viewModel) {
            viewModel.uninstallSelectedPackage()
            await waitForUninstallAttemptToFinish(on: viewModel)
            #expect(!viewModel.isMutatingPackage)
        }
    }

    @Test func `covering bulk upgrade marks detail upgrading and blocks the individual upgrade`() async {
        var package = InstalledBrewPackage.fixture(name: "git", kind: .formula)
        package.outdated = true
        // An "Upgrade All" already running when the detail appears — delivered via the seed snapshot.
        let center = BulkUpgradeRunningCommandCenter(running: [.bulkUpgrade(.all): .running(.upgradeAll)])
        let viewModel = makeInstalledDetailsViewModel(package: package, brewCommandCenter: center)

        await viewModel.observeRowUpdates()

        #expect(viewModel.isUpgrading)
        #expect(viewModel.isMutatingPackage)

        // The per-package upgrade must be a no-op while the covering batch runs.
        viewModel.upgradeSelectedPackage()
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        #expect(await center.performedIDs.isEmpty)
    }

    @Test func `observeRowUpdates clears blocked callout when uninstall starts`() async {
        let package = details(name: "ada-url")
        let viewModel = makeInstalledDetailsViewModel(
            package: package,
            brewCommandCenter: ConstantPhaseCommandCenter(
                phase: .running(.uninstallFormula),
                id: .package(package.id),
            ),
            installedDependentsRepository: StubInstalledDependentsRepository { packageID in
                packageID == package.id ? [InstalledBrewPackage.fixture(name: "curl")] : []
            },
        )

        await viewModel.refreshRelationships()
        viewModel.handleUninstallPrimaryButtonTapped()
        #expect(viewModel.showUninstallBlockedCallout)

        let observer = Task { await viewModel.observeRowUpdates() }
        defer { observer.cancel() }
        await waitForUninstalling(on: viewModel)

        #expect(!viewModel.showUninstallBlockedCallout)
    }
}

private actor BulkUpgradeRunningCommandCenter: BrewCommandCenter {
    private(set) var performedIDs: [BrewOperationID] = []
    private let running: [BrewOperationID: BrewOperationPhase]

    init(running: [BrewOperationID: BrewOperationPhase]) {
        self.running = running
    }

    func phase(for id: BrewOperationID) async -> BrewOperationPhase {
        running[id] ?? .idle
    }

    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] {
        running
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream { $0.finish() }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream { $0.finish() }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream { $0.finish() }
    }

    @discardableResult
    func capture(_: BrewCommand, id: BrewOperationID) async throws -> CommandOutput {
        performedIDs.append(id)
        return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }

    func perform(_ command: BrewCommand, id: BrewOperationID) async throws {
        _ = try await capture(command, id: id)
    }
}
