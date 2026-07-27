//
//  InstalledViewModelTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation
import Testing

struct InstalledViewModelTests {
    @Test @MainActor func `load exposes formula and cask rows in one list`() async {
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

    // MARK: - Keyboard navigation

    @Test @MainActor func `selectNext steps forward through the rows and stops at the last`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula), .fixture(name: "wget", kind: .formula)],
            casks: [.fixture(name: "slack", kind: .cask)],
        )
        let ordered = vm.loadedFormulaPackages.map(\.id) + vm.loadedCaskPackages.map(\.id)
        #expect(ordered.count == 3)

        vm.setSelection(ordered[0])
        vm.selectNext()
        #expect(vm.selectedPackage?.id == ordered[1])
        // Steps from a formula to a cask within the single interleaved list.
        vm.selectNext()
        #expect(vm.selectedPackage?.id == ordered[2])
        // Clamps at the final row.
        vm.selectNext()
        #expect(vm.selectedPackage?.id == ordered[2])
    }

    @Test @MainActor func `selectPrevious steps backward through the rows and stops at the first`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula), .fixture(name: "wget", kind: .formula)],
            casks: [.fixture(name: "slack", kind: .cask)],
        )
        let ordered = vm.loadedFormulaPackages.map(\.id) + vm.loadedCaskPackages.map(\.id)

        vm.setSelection(ordered[2])
        vm.selectPrevious()
        #expect(vm.selectedPackage?.id == ordered[1])
        vm.selectPrevious()
        #expect(vm.selectedPackage?.id == ordered[0])
        vm.selectPrevious()
        #expect(vm.selectedPackage?.id == ordered[0])
    }

    @Test @MainActor func `selectNext and selectPrevious are no-ops with an empty inventory`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel()
        #expect(vm.selectedPackage == nil)

        vm.selectNext()
        #expect(vm.selectedPackage == nil)
        vm.selectPrevious()
        #expect(vm.selectedPackage == nil)
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

    @Test @MainActor func `init with initialSelection picks that package when inventory contains it`() {
        let git = InstalledBrewPackage.fixture(name: "git", kind: .formula)
        let wget = InstalledBrewPackage.fixture(name: "wget", kind: .formula)
        let repo = StubInstalledPackagesRepository(packages: [git, wget])

        let vm = InstalledViewModel(repository: repo, initialSelection: wget.id)

        #expect(vm.selectedPackage?.id == wget.id)
    }

    @Test @MainActor func `init with initialSelection falls back to first row when id not in inventory`() {
        let git = InstalledBrewPackage.fixture(name: "git", kind: .formula)
        let missing = InstalledBrewPackage.ID.formula(name: "not-installed")
        let repo = StubInstalledPackagesRepository(packages: [git])

        let vm = InstalledViewModel(repository: repo, initialSelection: missing)

        // activeSelectedPackageID drops the candidate when it isn't in allRows
        // and falls back to firstVisibleRowID — the deep link doesn't strand
        // the UI on an empty selection.
        #expect(vm.selectedPackage?.id == git.id)
    }

    @Test @MainActor func `init with initialSelection applies once load completes`() async {
        let json = """
        {
          "formulae": [
            { "name": "git", "installed": [{ "version": "1.0.0" }] },
            { "name": "wget", "installed": [{ "version": "1.0.0" }] }
          ],
          "casks": []
        }
        """
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: QueuedBrewInfoRunner(infoJSON: [json]),
        )
        let target = InstalledBrewPackage.ID.formula(name: "wget")
        let vm = InstalledViewModel(repository: repo, initialSelection: target)

        // Repo is still .loading — allRows is empty so activeSelectedPackageID returns nil.
        #expect(vm.selectedPackage == nil)

        await vm.load()

        // Repo just landed in .loaded; the deep-link id is now in allRows so it resolves.
        #expect(vm.selectedPackage?.id == target)
    }

    @Test @MainActor func `load preserves brew stderr in user facing error state`() async {
        let vm = makeInstalledViewModel(
            repository: failingInstalledRepository(
                error: BrewCommandError.failed(exitCode: 1, stderr: "formula conflict"),
            ),
        )

        await vm.load()

        guard case let .failed(message) = vm.state else {
            Issue.record("expected error state")
            return
        }
        #expect(message == "formula conflict")
    }

    @Test @MainActor func `load maps brew lookup failure to missing Homebrew copy`() async {
        let vm = makeInstalledViewModel(repository: missingBrewInstalledRepository())

        await vm.load()

        guard case let .failed(message) = vm.state else {
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

        guard case let .failed(message) = vm.state else {
            Issue.record("expected error state")
            return
        }
        #expect(message == "spawn failed")
    }

    @Test @MainActor func `load maps unknown failure to generic load message`() async {
        let vm = makeInstalledViewModel(repository: failingInstalledRepository(error: OddRepositoryError()))

        await vm.load()

        guard case let .failed(message) = vm.state else {
            Issue.record("expected error state")
            return
        }
        #expect(message == InstalledPackagesTestSupport.localizedGenericLoadFailureMessage())
    }

    // MARK: - shouldFocusList

    @Test @MainActor func `shouldFocusList is false before the inventory has loaded`() {
        let vm = makeInstalledViewModel(repository: unloadedInstalledRepository())

        #expect(!vm.shouldFocusList)
    }

    @Test @MainActor func `shouldFocusList is true once the inventory has loaded`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
        )

        #expect(vm.shouldFocusList)
    }

    @Test @MainActor func `shouldFocusList is true when loaded with an empty inventory`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel()

        #expect(vm.shouldFocusList)
    }

    @Test @MainActor func `shouldFocusList is false when the load fails`() async {
        let vm = makeInstalledViewModel(repository: failingInstalledRepository(error: OddRepositoryError()))

        await vm.load()

        #expect(!vm.shouldFocusList)
    }

    @Test @MainActor func `shouldFocusList is false while the search field is presented`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
        )

        vm.isSearchFieldPresented = true

        #expect(!vm.shouldFocusList)
    }

    @Test @MainActor func `shouldFocusList returns to true once the search field is dismissed`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
        )

        vm.isSearchFieldPresented = true
        #expect(!vm.shouldFocusList)

        vm.isSearchFieldPresented = false
        #expect(vm.shouldFocusList)
    }
}
