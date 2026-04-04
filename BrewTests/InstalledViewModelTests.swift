//
//  InstalledViewModelTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

// MARK: - Snapshots (one logical assertion per load test)

private struct VMStateSnapshot: Equatable {
    var formulaRows: [InstalledPackageRow]
    var caskRows: [InstalledPackageRow]
    var userFacingError: String?
    var isLoading: Bool
    var totalPackageCount: Int

    /// Rows cleared, load finished, after a failed `load()`.
    static func emptyAfterLoad(userFacingError: String?) -> VMStateSnapshot {
        VMStateSnapshot(
            formulaRows: [],
            caskRows: [],
            userFacingError: userFacingError,
            isLoading: false,
            totalPackageCount: 0,
        )
    }
}

@MainActor
private func snapshot(_ vm: InstalledViewModel) -> VMStateSnapshot {
    VMStateSnapshot(
        formulaRows: vm.formulaRows,
        caskRows: vm.caskRows,
        userFacingError: vm.userFacingError,
        isLoading: vm.isLoading,
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

// MARK: - Tests

struct InstalledViewModelTests {
    @Test @MainActor func `load produces expected row snapshot`() async {
        let runner = MockBrewCommandRunner(responses: InstalledPackagesTestSupport.listVersionsResponses(
            formulaStandardOutput: "git 2.0\n",
            caskStandardOutput: "slack\n",
        ))
        let vm = await loadViewModel(commandRunner: runner)
        let expected = VMStateSnapshot(
            formulaRows: [
                InstalledPackageRow(name: "git", kind: .formula, description: "", installedVersion: "v2.0")
            ],
            caskRows: [
                InstalledPackageRow(name: "slack", kind: .cask, description: "", installedVersion: "—")
            ],
            userFacingError: nil,
            isLoading: false,
            totalPackageCount: 2,
        )
        #expect(snapshot(vm) == expected)
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
        #expect(vm.userFacingError == InstalledPackagesTestSupport.localizedHomebrewCommandFailedMessage())
    }

    @Test @MainActor func `load surfaces launch failure underlying message`() async {
        let runner = MockBrewCommandRunner(behaviors: [
            ["list", "--versions", "--formula"]: .throw(
                BrewCommandError.launchFailed(underlying: "posix spawn failed"),
            )
        ])
        let vm = await loadViewModel(commandRunner: runner)
        #expect(vm.userFacingError == "posix spawn failed")
    }

    @Test @MainActor func `load surfaces generic message for unknown repository errors`() async {
        let repo = StubThrowingRepository(error: OddRepositoryError())
        let vm = InstalledViewModel(repository: repo)
        await vm.load()
        #expect(vm.userFacingError == InstalledPackagesTestSupport.localizedGenericLoadFailureMessage())
    }
}
