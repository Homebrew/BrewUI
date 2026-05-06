//
//  InstalledViewModelTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

// MARK: - Repository stubs

private actor TwoSnapshotInstalledPackagesRepository: InstalledPackagesRepository {
    private let firstSnapshot: InstalledPackagesSnapshot
    private let secondSnapshot: InstalledPackagesSnapshot
    private var invocationCount = 0

    init(first: InstalledPackagesSnapshot, second: InstalledPackagesSnapshot) {
        firstSnapshot = first
        secondSnapshot = second
    }

    func loadInstalledPackages() async throws -> InstalledPackagesSnapshot {
        invocationCount += 1
        if invocationCount == 1 {
            return firstSnapshot
        }
        return secondSnapshot
    }
}

private actor RefreshRetryFailsRepository: InstalledPackagesRepository {
    private let successSnapshot: InstalledPackagesSnapshot
    private var invocationCount = 0

    init(successSnapshot: InstalledPackagesSnapshot) {
        self.successSnapshot = successSnapshot
    }

    func loadInstalledPackages() async throws -> InstalledPackagesSnapshot {
        invocationCount += 1
        if invocationCount == 1 {
            return successSnapshot
        }
        throw OddRepositoryError()
    }
}

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
        let vm = InstalledViewModel(
            repository: repo,
            detailsRepository: StubPackageDetailsRepository(),
        )
        await vm.load()
        #expect(vm.state == .error(InstalledPackagesTestSupport.localizedGenericLoadFailureMessage()))
    }

    @Test @MainActor func `toggleSelection updates selected row`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [InstalledPackageInfo(name: "git", version: "2.0")],
        )
        #expect(vm.loadedFormulaRows.first != nil)
        guard let selectedID = vm.loadedFormulaRows.first?.id else {
            return
        }
        vm.toggleSelection(for: selectedID)
        #expect(vm.selectedPackageRow?.id == selectedID)
    }

    @Test @MainActor func `clearSelection clears selected row`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [InstalledPackageInfo(name: "git", version: "2.0")],
        )
        #expect(vm.loadedFormulaRows.first != nil)
        guard let selectedID = vm.loadedFormulaRows.first?.id else {
            return
        }
        vm.toggleSelection(for: selectedID)
        vm.clearSelection()
        #expect(vm.selectedPackageRow == nil)
    }

    @Test @MainActor func `refreshInstalledPackagesPreservingUI updates content without loading state`() async {
        let firstSnapshot = InstalledPackagesSnapshot(
            formulae: [InstalledPackageInfo(name: "git", version: "2.0")],
            casks: [],
        )
        let secondSnapshot = InstalledPackagesSnapshot(
            formulae: [InstalledPackageInfo(name: "git", version: "3.0")],
            casks: [],
        )
        let repo = TwoSnapshotInstalledPackagesRepository(first: firstSnapshot, second: secondSnapshot)
        let vm = InstalledViewModel(
            repository: repo,
            detailsRepository: StubPackageDetailsRepository(),
        )
        await vm.load()
        #expect(vm.state.isLoaded)
        #expect(vm.loadedFormulaRows.first?.installedVersion == "v2.0")

        await vm.refreshInstalledPackagesPreservingUI()

        #expect(vm.state.isLoaded)
        #expect(vm.loadedFormulaRows.first?.installedVersion == "v3.0")
    }

    @Test @MainActor func `refreshInstalledPackagesPreservingUI keeps loaded state when refresh fails`() async {
        let snapshot = InstalledPackagesSnapshot(
            formulae: [InstalledPackageInfo(name: "git", version: "2.0")],
            casks: [],
        )
        let repo = RefreshRetryFailsRepository(successSnapshot: snapshot)
        let vm = InstalledViewModel(
            repository: repo,
            detailsRepository: StubPackageDetailsRepository(),
        )
        await vm.load()
        #expect(vm.loadedFormulaRows.first?.installedVersion == "v2.0")

        await vm.refreshInstalledPackagesPreservingUI()

        #expect(vm.state.isLoaded)
        #expect(vm.loadedFormulaRows.first?.installedVersion == "v2.0")
    }

    @Test @MainActor func `rowForInstalledPackageInfo maps version and upgrade labels consistently`() {
        let info = InstalledPackageInfo(
            name: "wget",
            version: "1.24.5",
            upgradeToVersion: "1.26.0",
        )

        let row = InstalledViewModel.rowForInstalledPackageInfo(info, kind: .formula)

        #expect(row.name == "wget")
        #expect(row.kind == .formula)
        #expect(row.installedVersion == "v1.24.5")
        #expect(row.updateVersion == "v1.26.0")
    }
}
