//
//  InstalledDetailMutationParityTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import BrewRepositoriesLive
import BrewRepositoriesTestSupport
import BrewServicesTestSupport
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

    @Test func `observeRowUpdates clears blocked callout when uninstall starts`() async {
        let package = details(name: "ada-url")
        let viewModel = makeInstalledDetailsViewModel(
            package: package,
            brewCommandCenter: ConstantPhaseCommandCenter(phase: .running(.uninstallFormula)),
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
