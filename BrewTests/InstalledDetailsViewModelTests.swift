//
//  InstalledDetailsViewModelTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct InstalledDetailsViewModelTests {
    @Test @MainActor func `displayCommand uses selected row name before load`() {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.displayCommand == "brew info wget")
    }

    @Test @MainActor func `displayCommand uses loaded details name after load`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: SuccessDetailsRepository(details: details(name: "wget@2")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: isLoaded)
        #expect(viewModel.displayCommand == "brew info wget@2")
    }

    @Test @MainActor func `homepageURL returns valid http URL from loaded details`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        var loadedDetails = details(name: "wget")
        loadedDetails.homepage = "https://example.com"
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: SuccessDetailsRepository(details: loadedDetails),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: isLoaded)

        #expect(viewModel.homepageURL?.absoluteString == "https://example.com")
    }

    @Test @MainActor func `homepageURL returns nil for invalid homepage`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        var loadedDetails = details(name: "wget")
        loadedDetails.homepage = "not-a-url"
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: SuccessDetailsRepository(details: loadedDetails),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: isLoaded)

        #expect(viewModel.homepageURL == nil)
    }

    @Test @MainActor func `homepageURL returns nil outside loaded state`() {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )

        #expect(viewModel.homepageURL == nil)
    }

    @Test @MainActor func `load maps package not found to user-facing error`() async {
        let row = InstalledPackageRow(name: "ghost", kind: .formula, description: "", installedVersion: "v1")
        let repository = StubDetailsRepository(error: PackageDetailsRepositoryError.packageNotFound(name: "ghost"))
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: repository,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: {
            if case .error = $0 {
                return true
            }
            return false
        })

        let expected = String(
            localized: "Could not load package details from Homebrew.",
            comment: "Installed detail error when package is missing in brew info JSON response",
        )
        #expect(viewModel.state == .error(expected))
    }

    @Test @MainActor func `load maps stderr from brew command failure`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let repository = StubDetailsRepository(error: BrewCommandError.failed(exitCode: 1, stderr: "permission denied"))
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: repository,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: {
            if case .error = $0 {
                return true
            }
            return false
        })

        #expect(viewModel.state == .error("permission denied"))
    }

    @Test @MainActor func `later load result wins when previous request finishes last`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let repository = DeferredDetailsRepository()
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: repository,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )

        viewModel.load()
        await repository.waitForCallCount(1)
        viewModel.load()
        await repository.waitForCallCount(2)

        await repository.resolve(callIndex: 1, with: .success(details(name: "wget-second")))
        await waitForState(on: viewModel, toSatisfy: {
            if case let .loaded(details) = $0 {
                return details.name == "wget-second"
            }
            return false
        })

        await repository.resolve(callIndex: 0, with: .success(details(name: "wget-first")))
        await Task.yield()

        guard case let .loaded(loadedDetails) = viewModel.state else {
            Issue.record("expected loaded state after second request result")
            return
        }
        #expect(loadedDetails.name == "wget-second")
    }

    @Test @MainActor func `upgradeDisplayCommand reflects formula name`() {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradeDisplayCommand == "brew upgrade wget")
    }

    @Test @MainActor func `upgradeDisplayCommand uses cask terminal flags`() {
        let row = InstalledPackageRow(
            name: "docker",
            kind: .cask,
            description: "",
            installedVersion: "v1",
        )
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: SuccessDetailsRepository(details: details(name: "docker", kind: .cask)),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        #expect(viewModel.upgradeDisplayCommand == "brew upgrade --cask docker")
    }

    @Test @MainActor func `upgradeDisplayCommand prefers loaded details package name`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: SuccessDetailsRepository(details: details(name: "wget@2")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: isLoaded)
        #expect(viewModel.upgradeDisplayCommand == "brew upgrade wget@2")
    }

    @Test @MainActor func `showsUpgradeChrome follows loaded details outdated flag`() async {
        var outdatedDetails = details(name: "wget")
        outdatedDetails.outdated = true
        let outdatedVM = InstalledDetailsViewModel(
            selection: PackageSelection(name: "wget", kind: .formula),
            repository: SuccessDetailsRepository(details: outdatedDetails),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        outdatedVM.load()
        await waitForState(on: outdatedVM, toSatisfy: isLoaded)
        #expect(outdatedVM.showsUpgradeChrome)

        var currentDetails = details(name: "wget")
        currentDetails.outdated = false
        let currentVM = InstalledDetailsViewModel(
            selection: PackageSelection(name: "wget", kind: .formula),
            repository: SuccessDetailsRepository(details: currentDetails),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        currentVM.load()
        await waitForState(on: currentVM, toSatisfy: isLoaded)
        #expect(!currentVM.showsUpgradeChrome)
    }

    @Test @MainActor func `upgradePrimaryButtonTitle is nil when package is current`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: isLoaded)
        #expect(viewModel.upgradePrimaryButtonTitle == nil)
    }

    @Test @MainActor func `upgradePrimaryButtonTitle includes available version label`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        var outdatedDetails = details(name: "wget")
        outdatedDetails.outdated = true
        outdatedDetails.availableVersion = "9.9.9"
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: SuccessDetailsRepository(details: outdatedDetails),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: isLoaded)
        #expect(viewModel.upgradePrimaryButtonTitle?.contains("v9.9.9") == true)
    }

    @Test @MainActor func `load syncs upgradeOperationPhase from command center`() async {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        let center = ConstantPhaseCommandCenter(phase: .running(.upgradeFormula))
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: center,
        )
        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: isLoaded)
        await waitForUpgradePhase(on: viewModel) { phase in
            if case .running(.upgradeFormula) = phase {
                return true
            }
            return false
        }
    }
}

struct InstalledDetailsViewModelUpgradeTests {
    @Test @MainActor func `upgrade invokes onUpgradeSuccess`() async {
        let spy = UpgradeCallbackSpy()
        let row = InstalledPackageRow(
            name: "wget",
            kind: .formula,
            description: "",
            installedVersion: "v1",
            updateVersion: "v2",
        )
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            onUpgradeSuccess: { await spy.record() },
        )

        viewModel.upgradeSelectedPackage()
        await waitForUpgradeCallback(spy: spy, expectedCount: 1)
        #expect(await spy.invocationCount == 1)
        #expect(viewModel.upgradeErrorMessage == nil)
    }

    @Test @MainActor func `upgrade failure sets upgrade error message`() async {
        let row = InstalledPackageRow(
            name: "wget",
            kind: .formula,
            description: "",
            installedVersion: "v1",
            updateVersion: "v2",
        )
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: ThrowingSubmitCommandCenter(
                error: BrewCommandError.failed(exitCode: 1, stderr: "upgrade blocked"),
            ),
        )

        viewModel.upgradeSelectedPackage()
        await waitForUpgradeError(on: viewModel)
        #expect(viewModel.upgradeErrorMessage == "upgrade blocked")
    }

    @Test @MainActor func `upgrade submit continues after caller task cancellation`() async {
        let row = InstalledPackageRow(
            name: "wget",
            kind: .formula,
            description: "",
            installedVersion: "v1",
            updateVersion: "v2",
        )
        let center = DeferredSubmitCommandCenter()
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: row.name, kind: row.kind),
            repository: SuccessDetailsRepository(details: details(name: "wget")),
            brewCommandCenter: center,
        )

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

    @Test @MainActor func `upgrade success refreshes details without loading flicker`() async {
        let repository = SequencedDetailsRepository(
            results: [
                .success(details(name: "wget", version: "1.0.0")),
                .success(details(name: "wget", version: "2.0.0")),
            ],
        )
        let viewModel = InstalledDetailsViewModel(
            selection: PackageSelection(name: "wget", kind: .formula),
            repository: repository,
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
        )

        viewModel.load()
        await waitForState(on: viewModel, toSatisfy: isLoaded)
        guard case let .loaded(beforeUpgrade) = viewModel.state else {
            Issue.record("expected loaded state before upgrade")
            return
        }
        #expect(beforeUpgrade.version == "1.0.0")

        viewModel.upgradeSelectedPackage()
        await repository.waitForCallCount(2)
        await waitForState(on: viewModel, toSatisfy: {
            if case let .loaded(details) = $0 {
                return details.version == "2.0.0"
            }
            return false
        })
        #expect(await repository.callCount == 2)
    }
}
