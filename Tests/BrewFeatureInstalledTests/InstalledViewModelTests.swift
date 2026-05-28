//
//  InstalledViewModelTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import BrewRepositories
import BrewRepositoriesTestSupport
import BrewServicesTestSupport
import Foundation
import Testing

struct InstalledViewModelTests {
    @Test @MainActor func `load produces expected package sections`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
            casks: [.fixture(name: "slack", kind: .cask)],
        )
        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.formulaPackages.count == 1)
        #expect(content.caskPackages.count == 1)
        #expect(vm.totalPackageCount == 2)
    }

    @Test @MainActor func `setSelection updates selected package`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
        )
        guard let selectedID = vm.loadedFormulaPackages.first?.id else { return }
        vm.setSelection(selectedID)
        #expect(vm.selectedPackage?.id == selectedID)
    }

    @Test @MainActor func `setSelection nil resolves to first visible package`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
        )
        guard let selectedID = vm.loadedFormulaPackages.first?.id else { return }
        vm.setSelection(selectedID)
        #expect(vm.selectedPackage?.id == selectedID)

        vm.setSelection(nil)
        // `nil` selection resolves to the first visible row (always-on list selection).
        #expect(vm.selectedPackage?.id == selectedID)
    }

    @Test @MainActor func `clearSelection resets to first visible package`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
        )
        guard let selectedID = vm.loadedFormulaPackages.first?.id else { return }
        vm.setSelection(selectedID)
        vm.clearSelection()
        #expect(vm.selectedPackage?.id == selectedID)
    }

    @Test @MainActor func `refresh preserves selection when package still exists`() async {
        let firstJSON = """
        {
          "formulae": [
            { "name": "git", "installed": [{ "version": "1.0.0" }] },
            { "name": "wget", "installed": [{ "version": "1.0.0" }] }
          ],
          "casks": []
        }
        """
        let secondJSON = """
        {
          "formulae": [
            { "name": "git", "installed": [{ "version": "2.0.0" }] },
            { "name": "wget", "installed": [{ "version": "1.0.0" }] }
          ],
          "casks": []
        }
        """
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: QueuedBrewInfoRunner(infoJSON: [firstJSON, secondJSON]),
        )
        let vm = makeInstalledViewModel(repository: repo)
        await vm.load()
        guard let selectedID = vm.loadedFormulaPackages.first?.id else { return }
        vm.setSelection(selectedID)

        await vm.refresh()

        #expect(vm.selectedPackage?.id == selectedID)
    }

    @Test @MainActor func `refresh repoints selection when selected package disappears`() async {
        let firstJSON = """
        {
          "formulae": [
            { "name": "git", "installed": [{ "version": "1.0.0" }] },
            { "name": "wget", "installed": [{ "version": "1.0.0" }] }
          ],
          "casks": []
        }
        """
        let secondJSON = """
        { "formulae": [{ "name": "wget", "installed": [{ "version": "1.0.0" }] }], "casks": [] }
        """
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: QueuedBrewInfoRunner(infoJSON: [firstJSON, secondJSON]),
        )
        let vm = makeInstalledViewModel(repository: repo)
        await vm.load()
        vm.setSelection(.formula(name: "git"))

        await vm.refresh()

        #expect(vm.selectedPackage?.id == .formula(name: "wget"))
    }

    @Test @MainActor func `load preserves brew stderr in user facing error state`() async {
        let vm = makeInstalledViewModel(
            repository: failingInstalledRepository(
                error: BrewCommandError.failed(exitCode: 1, stderr: "formula conflict"),
            ),
        )

        await vm.load()

        guard case let .error(message) = vm.state else {
            Issue.record("expected error state")
            return
        }
        #expect(message == "formula conflict")
    }

    @Test @MainActor func `load maps brew lookup failure to missing Homebrew copy`() async {
        let vm = makeInstalledViewModel(repository: missingBrewInstalledRepository())

        await vm.load()

        guard case let .error(message) = vm.state else {
            Issue.record("expected error state")
            return
        }
        #expect(message == InstalledPackagesTestSupport.localizedBrewExecutableNotFoundMessage())
    }

    @Test @MainActor func `load maps launch failure to underlying message`() async {
        let vm = makeInstalledViewModel(
            repository: failingInstalledRepository(
                error: BrewCommandError.launchFailed(underlying: "spawn failed"),
            ),
        )

        await vm.load()

        guard case let .error(message) = vm.state else {
            Issue.record("expected error state")
            return
        }
        #expect(message == "spawn failed")
    }

    @Test @MainActor func `load maps unknown failure to generic load message`() async {
        let vm = makeInstalledViewModel(repository: failingInstalledRepository(error: OddRepositoryError()))

        await vm.load()

        guard case let .error(message) = vm.state else {
            Issue.record("expected error state")
            return
        }
        #expect(message == InstalledPackagesTestSupport.localizedGenericLoadFailureMessage())
    }
}
