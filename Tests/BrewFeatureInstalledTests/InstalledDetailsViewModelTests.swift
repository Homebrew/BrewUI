//
//  InstalledDetailsViewModelTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
@testable import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation
import Testing

struct InstalledDetailsViewModelTests {
    @Test @MainActor func `packageName uses package display name`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: InstalledBrewPackage.fixture(
                name: "visual-studio-code",
                displayName: "Visual Studio Code",
                kind: .cask,
            ),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.packageName == "Visual Studio Code")
    }

    @Test @MainActor func `homepageURL returns valid http URL from package`() {
        var loadedDetails = details(name: "wget")
        loadedDetails.homepage = "https://example.com"
        let viewModel = makeInstalledDetailsViewModel(
            package: loadedDetails,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.homepageURL?.absoluteString == "https://example.com")
    }

    @Test @MainActor func `homepageURL returns nil for invalid homepage`() {
        var loadedDetails = details(name: "wget")
        loadedDetails.homepage = "not-a-url"
        let viewModel = makeInstalledDetailsViewModel(
            package: loadedDetails,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.homepageURL == nil)
    }

    @Test @MainActor func `homepageURL returns nil when homepage empty`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.homepageURL == nil)
    }

    @Test @MainActor func `upgradeDisplayCommand reflects formula name`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: InstalledBrewPackage.fixture(name: "wget", kind: .formula),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradeItem.displayCommand == "brew upgrade --formula wget")
    }

    @Test @MainActor func `upgradeDisplayCommand uses cask terminal flags`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: InstalledBrewPackage.fixture(name: "docker", kind: .cask),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradeItem.displayCommand == "brew upgrade --cask docker")
    }

    @Test @MainActor func `upgradeDisplayCommand updates when package name changes`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: InstalledBrewPackage.fixture(name: "wget", kind: .formula),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.update(package: details(name: "wget@2"))
        #expect(viewModel.upgradeItem.displayCommand == "brew upgrade --formula wget@2")
    }

    @Test @MainActor func `uninstallDisplayCommand reflects formula name`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: InstalledBrewPackage.fixture(name: "wget", kind: .formula),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.uninstallItem.displayCommand == "brew uninstall --formula wget")
    }

    @Test @MainActor func `uninstallDisplayCommand uses cask terminal flags`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: InstalledBrewPackage.fixture(name: "docker", kind: .cask),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.uninstallItem.displayCommand == "brew uninstall --cask docker")
    }

    @Test @MainActor func `uninstallDisplayCommand updates when package name changes`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: InstalledBrewPackage.fixture(name: "wget", kind: .formula),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.update(package: details(name: "wget@2"))
        #expect(viewModel.uninstallItem.displayCommand == "brew uninstall --formula wget@2")
    }

    @Test @MainActor func `showsUpgradeChrome follows package outdated flag`() {
        var outdatedDetails = details(name: "wget")
        outdatedDetails.outdated = true
        let outdatedVM = makeInstalledDetailsViewModel(
            package: outdatedDetails,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(outdatedVM.upgradeItem.showsUpgradeChrome)

        var currentDetails = details(name: "wget")
        currentDetails.outdated = false
        let currentVM = makeInstalledDetailsViewModel(
            package: currentDetails,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(!currentVM.upgradeItem.showsUpgradeChrome)
    }

    @Test @MainActor func `upgradePrimaryButtonTitle is nil when package is current`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradeItem.primaryButtonTitle == nil)
    }

    @Test @MainActor func `upgradePrimaryButtonTitle includes available version label`() {
        var outdatedDetails = details(name: "wget")
        outdatedDetails.outdated = true
        outdatedDetails.latestVersion = "9.9.9"
        let viewModel = makeInstalledDetailsViewModel(
            package: outdatedDetails,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradeItem.primaryButtonTitle?.contains("v9.9.9") == true)
    }

    @Test @MainActor func `update package mutates derived presentation for upgrade button`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget", version: "1.0.0"),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradeItem.primaryButtonTitle == nil)

        var newer = details(name: "wget", version: "2.0.0")
        newer.outdated = true
        newer.latestVersion = "2.0.0"
        viewModel.update(package: newer)
        #expect(viewModel.upgradeItem.primaryButtonTitle?.contains("v2.0.0") == true)
    }

    @Test @MainActor func `uninstall presentation uses package name`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: InstalledBrewPackage.fixture(name: "wget", kind: .formula),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.uninstallItem.primaryButtonTitle == "Uninstall")
        #expect(viewModel.uninstallItem.confirmationTitle == "Uninstall wget?")
        #expect(viewModel.uninstallItem.confirmationMessage == "This will remove wget from this Mac using Homebrew.")
    }

    @Test @MainActor func `detail row is not upgrading before observeRowUpdates runs`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: ConstantPhaseCommandCenter(phase: .running(.upgradeFormula)),
        )
        #expect(!viewModel.isUpgrading)
    }

    @Test @MainActor func `blocked uninstall primary button presentation`() async {
        let package = details(name: "ada-url")
        let viewModel = makeInstalledDetailsViewModel(
            package: package,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            installedDependentsRepository: StubInstalledDependentsRepository { packageID in
                packageID == package.id ? [InstalledBrewPackage.fixture(name: "curl")] : []
            },
        )
        await viewModel.refreshRelationships()
        #expect(viewModel.showsUninstallBlockedPrimaryButtonChrome)
        #expect(viewModel.uninstallPrimaryButtonAction == .revealBlockedExplanation)
        #expect(viewModel.uninstallItem.blockedCalloutContent != nil)
    }

    @Test @MainActor func `dependents uses injected repository for current package`() async {
        let package = details(name: "openssl@3")
        let viewModel = makeInstalledDetailsViewModel(
            package: package,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            installedDependentsRepository: StubInstalledDependentsRepository { packageID in
                packageID == package.id
                    ? [InstalledBrewPackage.fixture(name: "curl"), InstalledBrewPackage.fixture(name: "node")]
                    : []
            },
        )
        await viewModel.refreshRelationships()
        #expect(viewModel.dependentRelationships.map(\.displayName) == ["curl", "node"])
        #expect(viewModel.dependentRelationships.map(\.packageKind) == [.formula, .formula])
        #expect(viewModel.dependentRelationships.map(\.isInstalledInInventory) == [true, true])
    }

    @Test @MainActor func `update package refreshes dependents from repository`() async {
        let openssl = details(name: "openssl@3")
        let wget = details(name: "wget")
        let viewModel = makeInstalledDetailsViewModel(
            package: openssl,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            installedDependentsRepository: StubInstalledDependentsRepository { packageID in
                packageID == wget.id ? [InstalledBrewPackage.fixture(name: "curl")] : []
            },
        )
        await viewModel.refreshRelationships()
        viewModel.update(package: wget)
        await viewModel.refreshRelationships()
        #expect(viewModel.dependentRelationships.map(\.displayName) == ["curl"])
    }

    @Test @MainActor func `refreshRelationships marks installed and missing dependency refs`() async {
        let package = InstalledBrewPackage.fixture(
            name: "wget",
            kind: .formula,
            dependencies: [.formula(name: "openssl@3"), .formula(name: "zlib")],
        )
        let viewModel = makeInstalledDetailsViewModel(
            package: package,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: [.formula(name: "openssl@3")]),
        )

        await viewModel.refreshRelationships()

        #expect(viewModel.dependencyRelationships.count == 2)
        #expect(viewModel.dependencyRelationships[0].displayName == "openssl@3")
        #expect(viewModel.dependencyRelationships[0].packageKind == .formula)
        #expect(viewModel.dependencyRelationships[0].isInstalledInInventory)
        #expect(viewModel.dependencyRelationships[1].displayName == "zlib")
        #expect(viewModel.dependencyRelationships[1].packageKind == .formula)
        #expect(!viewModel.dependencyRelationships[1].isInstalledInInventory)
    }

    @Test @MainActor func `update package retains dependency relationships until refresh`() async {
        let viewModel = makeInstalledDetailsViewModel(
            package: InstalledBrewPackage.fixture(
                name: "wget",
                kind: .formula,
                dependencies: [.formula(name: "openssl@3")],
            ),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            installedInventoryReading: StubInstalledInventoryReading(installedIDs: [.formula(name: "openssl@3")]),
        )
        await viewModel.refreshRelationships()
        #expect(!viewModel.dependencyRelationships.isEmpty)
        // Stale relationships are kept until the async refresh for the new package completes,
        // preventing a visible flicker through an empty state on package change.
        viewModel.update(package: InstalledBrewPackage.fixture(name: "curl", kind: .formula))
        #expect(!viewModel.dependencyRelationships.isEmpty)
        await viewModel.refreshRelationships()
        #expect(viewModel.dependencyRelationships.isEmpty)
    }

    @Test @MainActor func `update package retains dependent relationships until refresh`() async {
        let package = details(name: "openssl@3")
        let viewModel = makeInstalledDetailsViewModel(
            package: package,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            installedDependentsRepository: StubInstalledDependentsRepository { packageID in
                packageID == package.id ? [InstalledBrewPackage.fixture(name: "curl")] : []
            },
        )
        await viewModel.refreshRelationships()
        #expect(!viewModel.dependentRelationships.isEmpty)
        // Stale relationships are kept until the async refresh for the new package completes,
        // preventing a visible flicker through an empty state on package change.
        viewModel.update(package: InstalledBrewPackage.fixture(name: "wget", kind: .formula))
        #expect(!viewModel.dependentRelationships.isEmpty)
        await viewModel.refreshRelationships()
        #expect(viewModel.dependentRelationships.isEmpty)
    }

    @Test @MainActor func `detail row is not uninstalling before observeRowUpdates runs`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: ConstantPhaseCommandCenter(phase: .running(.uninstallFormula)),
        )
        #expect(!viewModel.isUninstalling)
    }

    @Test @MainActor func `showsUpgradeAvailable is false when package is current`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(!viewModel.showsUpgradeAvailable)
    }

    @Test @MainActor func `showsUpgradeAvailable is true when package is outdated`() {
        var outdatedDetails = details(name: "wget")
        outdatedDetails.outdated = true
        let viewModel = makeInstalledDetailsViewModel(
            package: outdatedDetails,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.showsUpgradeAvailable)
    }

    @Test @MainActor func `showsUpgradeAvailable updates when package changes to outdated`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(!viewModel.showsUpgradeAvailable)

        var outdatedDetails = details(name: "wget")
        outdatedDetails.outdated = true
        viewModel.update(package: outdatedDetails)
        #expect(viewModel.showsUpgradeAvailable)
    }
}

struct InstalledDetailsViewModelUpgradeTests {
    @Test @MainActor func `upgrade completes with idle phase and no error using noop center`() async {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )

        await withInstalledDetailPhaseObservation(on: viewModel) {
            viewModel.upgradeSelectedPackage()
            await waitForUpgradeAttemptToFinish(on: viewModel)
            #expect(viewModel.upgradeErrorMessage == nil)
        }
    }

    @Test @MainActor func `upgrade failure sets upgrade error message`() async {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: ThrowingSubmitCommandCenter(
                error: BrewCommandError.failed(exitCode: 1, stderr: "upgrade blocked"),
            ),
        )

        await withInstalledDetailPhaseObservation(on: viewModel) {
            viewModel.upgradeSelectedPackage()
            await waitForUpgradeError(on: viewModel)
            #expect(viewModel.upgradeErrorMessage == "upgrade blocked")
        }
    }

    @Test @MainActor func `upgrade ignores reentry while already upgrading`() async {
        let center = RunningSubmitCountingCommandCenter()
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: center,
        )

        viewModel.upgradeSelectedPackage()
        let observer = Task { await viewModel.observeRowUpdates() }
        defer { observer.cancel() }

        await waitForUpgrading(on: viewModel)
        viewModel.upgradeSelectedPackage()

        #expect(await center.submitCallCount == 1)
    }

    @Test @MainActor func `upgrade failure maps missing brew to user facing message`() async {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: ThrowingSubmitCommandCenter(
                error: BrewLookupError.executableNotFound,
            ),
        )

        await withInstalledDetailPhaseObservation(on: viewModel) {
            viewModel.upgradeSelectedPackage()
            await waitForUpgradeError(on: viewModel)
            #expect(
                viewModel.upgradeErrorMessage ==
                    "Could not find Homebrew. Install it or ensure brew is in the default location.",
            )
        }
    }

    @Test @MainActor func `upgrade failure maps launch failure to underlying message`() async {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: ThrowingSubmitCommandCenter(
                error: BrewCommandError.launchFailed(underlying: "spawn failed"),
            ),
        )

        await withInstalledDetailPhaseObservation(on: viewModel) {
            viewModel.upgradeSelectedPackage()
            await waitForUpgradeError(on: viewModel)
            #expect(viewModel.upgradeErrorMessage == "spawn failed")
        }
    }

    @Test @MainActor func `upgrade failure maps unknown errors to generic message`() async {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: ThrowingSubmitCommandCenter(
                error: GenericUpgradeError(),
            ),
        )

        await withInstalledDetailPhaseObservation(on: viewModel) {
            viewModel.upgradeSelectedPackage()
            await waitForUpgradeError(on: viewModel)
            #expect(viewModel.upgradeErrorMessage == "Something went wrong while upgrading this package.")
        }
    }

    @Test @MainActor func `upgrade submit continues after caller task cancellation`() async {
        let center = DeferredSubmitCommandCenter()
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: center,
        )

        await withInstalledDetailPhaseObservation(on: viewModel) {
            let callerTask = Task { @MainActor in
                viewModel.upgradeSelectedPackage()
            }
            callerTask.cancel()
            _ = await callerTask.result

            await center.waitForSubmitCallCount(1)
            #expect(await center.submitCallCount == 1)
            await center.resolveSubmit()
            await waitForUpgradeAttemptToFinish(on: viewModel)
        }
    }

    @Test @MainActor func `uninstall completes with idle phase and no error using noop center`() async {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )

        await withInstalledDetailPhaseObservation(on: viewModel) {
            viewModel.uninstallSelectedPackage()
            await waitForUninstallAttemptToFinish(on: viewModel)
            #expect(viewModel.uninstallErrorMessage == nil)
        }
    }

    @Test @MainActor func `uninstall failure sets uninstall error message`() async {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: ThrowingSubmitCommandCenter(
                error: BrewCommandError.failed(exitCode: 1, stderr: "uninstall blocked"),
            ),
        )

        await withInstalledDetailPhaseObservation(on: viewModel) {
            viewModel.uninstallSelectedPackage()
            await waitForUninstallError(on: viewModel)
            #expect(viewModel.uninstallErrorMessage == "uninstall blocked")
        }
    }

    @Test @MainActor func `uninstall ignores reentry while already uninstalling`() async {
        let center = RunningSubmitCountingCommandCenter(phase: .running(.uninstallFormula))
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: center,
        )

        viewModel.uninstallSelectedPackage()
        let observer = Task { await viewModel.observeRowUpdates() }
        defer { observer.cancel() }

        await waitForUninstalling(on: viewModel)
        viewModel.uninstallSelectedPackage()

        #expect(await center.submitCallCount == 1)
    }

    @Test @MainActor func `uninstall failure maps missing brew to user facing message`() async {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: ThrowingSubmitCommandCenter(
                error: BrewLookupError.executableNotFound,
            ),
        )

        await withInstalledDetailPhaseObservation(on: viewModel) {
            viewModel.uninstallSelectedPackage()
            await waitForUninstallError(on: viewModel)
            #expect(
                viewModel.uninstallErrorMessage ==
                    "Could not find Homebrew. Install it or ensure brew is in the default location.",
            )
        }
    }

    @Test @MainActor func `uninstall failure maps unknown errors to generic message`() async {
        let viewModel = makeInstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: ThrowingSubmitCommandCenter(
                error: GenericUpgradeError(),
            ),
        )

        await withInstalledDetailPhaseObservation(on: viewModel) {
            viewModel.uninstallSelectedPackage()
            await waitForUninstallError(on: viewModel)
            #expect(viewModel.uninstallErrorMessage == "Something went wrong while uninstalling this package.")
        }
    }
}

private struct GenericUpgradeError: Error {}

// MARK: - Uninstall presentation state

extension InstalledDetailsViewModelTests {
    @Test @MainActor func `handleUninstallPrimaryButtonTapped sets showUninstallConfirmation when not blocked`() {
        let viewModel = makeInstalledDetailsViewModel(
            package: InstalledBrewPackage.fixture(name: "wget", kind: .formula),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.handleUninstallPrimaryButtonTapped()
        #expect(viewModel.showUninstallConfirmation)
        #expect(!viewModel.showUninstallBlockedCallout)
    }

    @Test @MainActor func `handleUninstallPrimaryButtonTapped sets showUninstallBlockedCallout when blocked`() async {
        let package = details(name: "ada-url")
        let viewModel = makeInstalledDetailsViewModel(
            package: package,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            installedDependentsRepository: StubInstalledDependentsRepository { packageID in
                packageID == package.id ? [InstalledBrewPackage.fixture(name: "curl")] : []
            },
        )
        await viewModel.refreshRelationships()
        viewModel.handleUninstallPrimaryButtonTapped()
        #expect(viewModel.showUninstallBlockedCallout)
        #expect(!viewModel.showUninstallConfirmation)
    }

    @Test @MainActor func `update package clears uninstall presentation flags`() async {
        let package = details(name: "ada-url")
        let viewModel = makeInstalledDetailsViewModel(
            package: package,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            installedDependentsRepository: StubInstalledDependentsRepository { packageID in
                packageID == package.id ? [InstalledBrewPackage.fixture(name: "curl")] : []
            },
        )
        await viewModel.refreshRelationships()
        viewModel.handleUninstallPrimaryButtonTapped()
        #expect(viewModel.showUninstallBlockedCallout)
        viewModel.update(package: InstalledBrewPackage.fixture(name: "wget", kind: .formula))
        #expect(!viewModel.showUninstallBlockedCallout)
        #expect(!viewModel.showUninstallConfirmation)
    }
}
