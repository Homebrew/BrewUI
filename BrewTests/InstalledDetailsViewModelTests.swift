//
//  InstalledDetailsViewModelTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct InstalledDetailsViewModelTests {
    @Test @MainActor func `displayCommand uses package name`() {
        let viewModel = InstalledDetailsViewModel(
            package: .fixture(name: "wget", kind: .formula),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.displayCommand == "brew info wget")
    }

    @Test @MainActor func `displayCommand updates when package changes via update`() {
        let viewModel = InstalledDetailsViewModel(
            package: .fixture(name: "wget", kind: .formula),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.update(package: details(name: "wget@2"))
        #expect(viewModel.displayCommand == "brew info wget@2")
    }

    @Test @MainActor func `homepageURL returns valid http URL from package`() {
        var loadedDetails = details(name: "wget")
        loadedDetails.homepage = "https://example.com"
        let viewModel = InstalledDetailsViewModel(
            package: loadedDetails,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.homepageURL?.absoluteString == "https://example.com")
    }

    @Test @MainActor func `homepageURL returns nil for invalid homepage`() {
        var loadedDetails = details(name: "wget")
        loadedDetails.homepage = "not-a-url"
        let viewModel = InstalledDetailsViewModel(
            package: loadedDetails,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.homepageURL == nil)
    }

    @Test @MainActor func `homepageURL returns nil when homepage empty`() {
        let viewModel = InstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.homepageURL == nil)
    }

    @Test @MainActor func `upgradeDisplayCommand reflects formula name`() {
        let viewModel = InstalledDetailsViewModel(
            package: .fixture(name: "wget", kind: .formula),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradeDisplayCommand == "brew upgrade --formula wget")
    }

    @Test @MainActor func `upgradeDisplayCommand uses cask terminal flags`() {
        let viewModel = InstalledDetailsViewModel(
            package: .fixture(name: "docker", kind: .cask),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradeDisplayCommand == "brew upgrade --cask docker")
    }

    @Test @MainActor func `upgradeDisplayCommand updates when package name changes`() {
        let viewModel = InstalledDetailsViewModel(
            package: .fixture(name: "wget", kind: .formula),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.update(package: details(name: "wget@2"))
        #expect(viewModel.upgradeDisplayCommand == "brew upgrade --formula wget@2")
    }

    @Test @MainActor func `showsUpgradeChrome follows package outdated flag`() {
        var outdatedDetails = details(name: "wget")
        outdatedDetails.outdated = true
        let outdatedVM = InstalledDetailsViewModel(
            package: outdatedDetails,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(outdatedVM.showsUpgradeChrome)

        var currentDetails = details(name: "wget")
        currentDetails.outdated = false
        let currentVM = InstalledDetailsViewModel(
            package: currentDetails,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(!currentVM.showsUpgradeChrome)
    }

    @Test @MainActor func `upgradePrimaryButtonTitle is nil when package is current`() {
        let viewModel = InstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradePrimaryButtonTitle == nil)
    }

    @Test @MainActor func `upgradePrimaryButtonTitle includes available version label`() {
        var outdatedDetails = details(name: "wget")
        outdatedDetails.outdated = true
        outdatedDetails.latestVersion = "9.9.9"
        let viewModel = InstalledDetailsViewModel(
            package: outdatedDetails,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradePrimaryButtonTitle?.contains("v9.9.9") == true)
    }

    @Test @MainActor func `update package mutates derived presentation for upgrade button`() {
        let viewModel = InstalledDetailsViewModel(
            package: details(name: "wget", version: "1.0.0"),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradePrimaryButtonTitle == nil)

        var newer = details(name: "wget", version: "2.0.0")
        newer.outdated = true
        newer.latestVersion = "2.0.0"
        viewModel.update(package: newer)
        #expect(viewModel.upgradePrimaryButtonTitle?.contains("v2.0.0") == true)
    }

    @Test @MainActor func `upgradeOperationPhase starts idle without syncing command center`() {
        let viewModel = InstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: ConstantPhaseCommandCenter(phase: .running(.upgradeFormula)),
        )
        #expect(viewModel.upgradeOperationPhase == .idle)
    }
}

struct InstalledDetailsViewModelUpgradeTests {
    @Test @MainActor func `upgrade completes with idle phase and no error using noop center`() async {
        let viewModel = InstalledDetailsViewModel(
            package: details(name: "wget"),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )

        await withInstalledDetailPhaseObservation(on: viewModel) {
            viewModel.upgradeSelectedPackage()
            await waitForUpgradePhase(on: viewModel) { phase in
                if case .idle = phase {
                    return true
                }
                return false
            }
            #expect(viewModel.upgradeErrorMessage == nil)
        }
    }

    @Test @MainActor func `upgrade failure sets upgrade error message`() async {
        let viewModel = InstalledDetailsViewModel(
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

    @Test @MainActor func `upgrade submit continues after caller task cancellation`() async {
        let center = DeferredSubmitCommandCenter()
        let viewModel = InstalledDetailsViewModel(
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
            await waitForUpgradePhase(on: viewModel) { phase in
                if case .idle = phase {
                    return true
                }
                return false
            }
        }
    }
}
