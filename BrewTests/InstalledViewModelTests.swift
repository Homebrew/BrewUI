//
//  InstalledViewModelTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

// MARK: - Snapshots (one logical assertion per load test)

private struct VMStateSnapshot: Equatable {
    var state: InstalledLoadState
    var formulaRows: [InstalledPackageRow]
    var caskRows: [InstalledPackageRow]
    var selectedPackageID: InstalledPackageRow.ID?
    var totalPackageCount: Int

    /// Rows cleared, load finished, after a failed `load()`.
    static func emptyAfterLoad(userFacingError: String) -> VMStateSnapshot {
        VMStateSnapshot(
            state: .error(userFacingError),
            formulaRows: [],
            caskRows: [],
            selectedPackageID: nil,
            totalPackageCount: 0,
        )
    }
}

@MainActor
private func snapshot(_ vm: InstalledViewModel) -> VMStateSnapshot {
    VMStateSnapshot(
        state: vm.state,
        formulaRows: vm.formulaRows,
        caskRows: vm.caskRows,
        selectedPackageID: vm.selectedPackageID,
        totalPackageCount: vm.totalPackageCount,
    )
}

@MainActor
private func loadViewModel(
    commandRunner: BrewCommandRunning,
    locator: (any BrewExecutableLocating)? = nil,
) async -> InstalledViewModel {
    let repo = InstalledPackagesTestSupport.repository(commandRunner: commandRunner, locator: locator)
    let vm = InstalledViewModel(repository: repo)
    await vm.load()
    return vm
}

private struct OddRepositoryError: Error {}

private struct StubThrowingRepository: InstalledPackagesRepository {
    let error: Error

    func loadInstalledPackages() async throws -> InstalledPackagesSnapshot {
        throw error
    }
}

private struct StubInstalledRepository: InstalledPackagesRepository {
    let snapshot: InstalledPackagesSnapshot

    func loadInstalledPackages() async throws -> InstalledPackagesSnapshot {
        snapshot
    }
}

private struct StubPackageDetailsRepository: PackageDetailsRepository {
    func loadPackageDetails(named name: String, preferredKind: InstalledPackageKind?) async throws -> InstalledPackageDetails {
        InstalledPackageDetails(
            name: name,
            kind: preferredKind ?? .formula,
            description: "desc",
            version: "1.0.0",
            installedVersions: ["1.0.0"],
            homepage: nil,
            dependencies: [],
            command: "brew info \(name) --json=v2",
        )
    }
}

// MARK: - Tests

struct InstalledViewModelTests {
    @Test @MainActor func `load produces expected row snapshot`() async {
        let runner = MockBrewCommandRunner(responses: InstalledPackagesTestSupport.listVersionsResponses(
            formulaStandardOutput: "git 2.0\n",
            caskStandardOutput: "slack\n",
        ))
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
        let runner = MockBrewCommandRunner(responses: InstalledPackagesTestSupport.listVersionsResponses(
            formulaStandardOutput: "git 2.0\n",
            caskStandardOutput: "\n",
        ))
        let vm = await loadViewModel(commandRunner: runner)
        #expect(vm.totalPackageCount == 1)
        #expect(vm.selectedPackageID == nil)
    }

    @Test @MainActor func `ensureValidSelection clears invalid selection instead of selecting first row`() {
        let vm = InstalledViewModel(
            testingFormulaRows: [
                InstalledPackageRow(name: "git", kind: .formula, description: "", installedVersion: "v2.0"),
            ],
        )
        vm.selectedPackageID = "missing-id"
        vm.ensureValidSelection()
        #expect(vm.selectedPackageID == nil)
    }

    @Test @MainActor func `ensureValidSelection keeps existing valid selection`() {
        let row = InstalledPackageRow(name: "git", kind: .formula, description: "", installedVersion: "v2.0")
        let vm = InstalledViewModel(testingFormulaRows: [row])
        vm.selectedPackageID = row.id
        vm.ensureValidSelection()
        #expect(vm.selectedPackageID == row.id)
    }

    @Test @MainActor func `load maps formula version that already has lowercase v prefix`() async {
        let runner = MockBrewCommandRunner(responses: InstalledPackagesTestSupport.listVersionsResponses(
            formulaStandardOutput: "pkg v1.0\n",
            caskStandardOutput: "\n",
        ))
        let vm = await loadViewModel(commandRunner: runner)
        #expect(vm.formulaRows.first?.installedVersion == "v1.0")
    }

    @Test @MainActor func `load maps formula version that already has uppercase V prefix`() async {
        let runner = MockBrewCommandRunner(responses: InstalledPackagesTestSupport.listVersionsResponses(
            formulaStandardOutput: "pkg V1.0\n",
            caskStandardOutput: "\n",
        ))
        let vm = await loadViewModel(commandRunner: runner)
        #expect(vm.formulaRows.first?.installedVersion == "V1.0")
    }

    @Test @MainActor func `load with nil repository leaves state unchanged`() async {
        let formula = InstalledPackageRow(name: "x", kind: .formula, description: "", installedVersion: "v1")
        let vm = InstalledViewModel(previewFormulae: [formula], previewCasks: [])
        let before = snapshot(vm)
        await vm.load()
        #expect(snapshot(vm) == before)
    }

    @Test @MainActor func `load clears rows and sets localized message when brew executable missing`() async {
        let runner = MockBrewCommandRunner(responses: [:])
        let vm = await loadViewModel(commandRunner: runner, locator: MissingBrewExecutableLocator())
        let expected = VMStateSnapshot.emptyAfterLoad(
            userFacingError: InstalledPackagesTestSupport.localizedBrewExecutableNotFoundMessage(),
        )
        #expect(snapshot(vm) == expected)
    }

    @Test @MainActor func `load surfaces stderr when brew list fails`() async {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.responsesFormulaListFailure(
                standardError: "formula list failed",
                terminationStatus: 1,
            ),
        )
        let vm = await loadViewModel(commandRunner: runner)
        #expect(snapshot(vm) == VMStateSnapshot.emptyAfterLoad(userFacingError: "formula list failed"))
    }

    @Test @MainActor func `load surfaces generic message when brew list fails with whitespace only stderr`() async {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.responsesFormulaListFailure(
                standardError: "   \n",
                terminationStatus: 1,
            ),
        )
        let vm = await loadViewModel(commandRunner: runner)
        #expect(vm.state == .error(InstalledPackagesTestSupport.localizedHomebrewCommandFailedMessage()))
    }

    @Test @MainActor func `load surfaces launch failure underlying message`() async {
        let runner = MockBrewCommandRunner(behaviors: [
            ["list", "--versions", "--formula"]: .throw(
                BrewCommandError.launchFailed(underlying: "posix spawn failed"),
            ),
        ])
        let vm = await loadViewModel(commandRunner: runner)
        #expect(vm.state == .error("posix spawn failed"))
    }

    @Test @MainActor func `load surfaces generic message for unknown repository errors`() async {
        let repo = StubThrowingRepository(error: OddRepositoryError())
        let vm = InstalledViewModel(repository: repo)
        await vm.load()
        #expect(vm.state == .error(InstalledPackagesTestSupport.localizedGenericLoadFailureMessage()))
    }

    @Test @MainActor func `toggleSelection with details repository creates details view model`() async {
        let repo = StubInstalledRepository(snapshot: InstalledPackagesSnapshot(
            formulae: [InstalledPackageInfo(name: "git", version: "2.0")],
            casks: [],
        ))
        let vm = InstalledViewModel(
            repository: repo,
            detailsRepository: StubPackageDetailsRepository(),
        )
        await vm.load()
        #expect(vm.formulaRows.first != nil)
        guard let selectedID = vm.formulaRows.first?.id else {
            return
        }
        vm.toggleSelection(for: selectedID)
        #expect(vm.detailsViewModel != nil)
    }

    @Test @MainActor func `clearSelection clears details view model`() async {
        let repo = StubInstalledRepository(snapshot: InstalledPackagesSnapshot(
            formulae: [InstalledPackageInfo(name: "git", version: "2.0")],
            casks: [],
        ))
        let vm = InstalledViewModel(
            repository: repo,
            detailsRepository: StubPackageDetailsRepository(),
        )
        await vm.load()
        #expect(vm.formulaRows.first != nil)
        guard let selectedID = vm.formulaRows.first?.id else {
            return
        }
        vm.toggleSelection(for: selectedID)
        vm.clearSelection()
        #expect(vm.detailsViewModel == nil)
    }
}
