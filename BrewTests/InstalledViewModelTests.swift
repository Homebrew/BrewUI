//
//  InstalledViewModelTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

// MARK: - Tests

struct InstalledViewModelTests {
    @Test @MainActor func `load produces expected row snapshot`() async {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(
                standardOutput: """
                {
                  "formulae": [{ "name": "git", "installed": [{ "version": "2.0" }] }],
                  "casks": [{ "token": "slack" }]
                }
                """,
            ),
        )
        let vm = await loadViewModel(commandRunner: runner)
        let expected = VMStateSnapshot(
            state: .loaded(
                InstalledPackagesContent(
                    formulaRows: [
                        InstalledPackageRow(name: "git", kind: .formula, description: "", installedVersion: "v2.0"),
                    ],
                    caskRows: [
                        InstalledPackageRow(name: "slack", kind: .cask, description: "", installedVersion: "—"),
                    ],
                ),
            ),
            formulaRows: [
                InstalledPackageRow(name: "git", kind: .formula, description: "", installedVersion: "v2.0"),
            ],
            caskRows: [
                InstalledPackageRow(name: "slack", kind: .cask, description: "", installedVersion: "—"),
            ],
            selectedPackageID: nil,
            totalPackageCount: 2,
        )
        #expect(snapshot(vm) == expected)
    }

    @Test @MainActor func `load does not auto-select first package when rows are loaded`() async {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(
                standardOutput: """
                {
                  "formulae": [{ "name": "git", "installed": [{ "version": "2.0" }] }],
                  "casks": []
                }
                """,
            ),
        )
        let vm = await loadViewModel(commandRunner: runner)
        #expect(vm.totalPackageCount == 1)
        #expect(vm.selectedPackageID == nil)
    }

    @Test @MainActor func `load maps formula version that already has lowercase v prefix`() async {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(
                standardOutput: """
                {
                  "formulae": [{ "name": "pkg", "installed": [{ "version": "v1.0" }] }],
                  "casks": []
                }
                """,
            ),
        )
        let vm = await loadViewModel(commandRunner: runner)
        #expect(vm.loadedFormulaRows.first?.installedVersion == "v1.0")
    }

    @Test @MainActor func `load maps formula version that already has uppercase V prefix`() async {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(
                standardOutput: """
                {
                  "formulae": [{ "name": "pkg", "installed": [{ "version": "V1.0" }] }],
                  "casks": []
                }
                """,
            ),
        )
        let vm = await loadViewModel(commandRunner: runner)
        #expect(vm.loadedFormulaRows.first?.installedVersion == "V1.0")
    }

    @Test @MainActor func `load formats outdated upgrade target for list row`() async {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(
                standardOutput: """
                {
                  "formulae": [{
                    "name": "wget",
                    "outdated": true,
                    "versions": { "stable": "1.26.0" },
                    "installed": [{ "version": "1.24.5" }]
                  }],
                  "casks": []
                }
                """,
            ),
        )
        let vm = await loadViewModel(commandRunner: runner)
        let row = vm.loadedFormulaRows.first
        #expect(row?.installedVersion == "v1.24.5")
        #expect(row?.updateVersion == "v1.26.0")
    }

    @Test @MainActor func `load clears rows and sets localized message when brew executable missing`() async {
        let runner = MockBrewCommandRunner(responses: [:])
        let vm = await loadViewModel(commandRunner: runner, locator: MissingBrewExecutableLocator())
        let expected = VMStateSnapshot.emptyAfterLoad(
            userFacingError: InstalledPackagesTestSupport.localizedBrewExecutableNotFoundMessage(),
        )
        #expect(snapshot(vm) == expected)
    }

    @Test @MainActor func `load surfaces stderr when brew info fails`() async {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.responsesInstalledInfoFailure(
                standardError: "formula list failed",
                terminationStatus: 1,
            ),
        )
        let vm = await loadViewModel(commandRunner: runner)
        #expect(snapshot(vm) == VMStateSnapshot.emptyAfterLoad(userFacingError: "formula list failed"))
    }

    @Test @MainActor func `load surfaces generic message when brew info fails with whitespace only stderr`() async {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.responsesInstalledInfoFailure(
                standardError: "   \n",
                terminationStatus: 1,
            ),
        )
        let vm = await loadViewModel(commandRunner: runner)
        #expect(vm.state == .error(InstalledPackagesTestSupport.localizedHomebrewCommandFailedMessage()))
    }

    @Test @MainActor func `load surfaces launch failure underlying message`() async {
        let runner = MockBrewCommandRunner(behaviors: [
            ["info", "--installed", "--json=v2"]: .throw(
                BrewCommandError.launchFailed(underlying: "posix spawn failed"),
            ),
        ])
        let vm = await loadViewModel(commandRunner: runner)
        #expect(vm.state == .error("posix spawn failed"))
    }

    @Test @MainActor func `load surfaces generic message for unknown repository errors`() async {
        let repo = StubThrowingRepository(error: OddRepositoryError())
        let vm = InstalledViewModel(repository: repo, detailsRepository: StubPackageDetailsRepository())
        await vm.load()
        #expect(vm.state == .error(InstalledPackagesTestSupport.localizedGenericLoadFailureMessage()))
    }

    @Test @MainActor func `toggleSelection with details repository creates details view model`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [InstalledPackageInfo(name: "git", version: "2.0")],
        )
        #expect(vm.loadedFormulaRows.first != nil)
        guard let selectedID = vm.loadedFormulaRows.first?.id else {
            return
        }
        vm.toggleSelection(for: selectedID)
        #expect(vm.detailsViewModel != nil)
    }

    @Test @MainActor func `clearSelection clears details view model`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [InstalledPackageInfo(name: "git", version: "2.0")],
        )
        #expect(vm.loadedFormulaRows.first != nil)
        guard let selectedID = vm.loadedFormulaRows.first?.id else {
            return
        }
        vm.toggleSelection(for: selectedID)
        vm.clearSelection()
        #expect(vm.detailsViewModel == nil)
    }
}
