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
        formulaRows: vm.loadedFormulaRows,
        caskRows: vm.loadedCaskRows,
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
    let vm = InstalledViewModel(repository: repo, detailsRepository: StubPackageDetailsRepository())
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

    @Test @MainActor func `searchQuery didSet filters loaded formula and cask rows case insensitively`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                InstalledPackageInfo(name: "Git", version: "2.0"),
                InstalledPackageInfo(name: "wget", version: "1.0"),
            ],
            casks: [
                InstalledPackageInfo(name: "GitHub", version: nil),
                InstalledPackageInfo(name: "Slack", version: nil),
            ],
        )
        vm.searchQuery = "git"
        #expect(
            snapshot(vm) == VMStateSnapshot(
                state: .loaded(
                    InstalledPackagesContent(
                        formulaRows: [
                            InstalledPackageRow(name: "Git", kind: .formula, description: "", installedVersion: "v2.0"),
                        ],
                        caskRows: [
                            InstalledPackageRow(name: "GitHub", kind: .cask, description: "", installedVersion: "—"),
                        ],
                    ),
                ),
                formulaRows: [
                    InstalledPackageRow(name: "Git", kind: .formula, description: "", installedVersion: "v2.0"),
                ],
                caskRows: [
                    InstalledPackageRow(name: "GitHub", kind: .cask, description: "", installedVersion: "—"),
                ],
                selectedPackageID: nil,
                totalPackageCount: 2,
            ),
        )
    }

    @Test @MainActor func `searchQuery didSet whitespace query restores all loaded rows`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                InstalledPackageInfo(name: "git", version: "2.0"),
                InstalledPackageInfo(name: "wget", version: "1.0"),
            ],
            casks: [
                InstalledPackageInfo(name: "slack", version: nil),
            ],
        )
        vm.searchQuery = "git"
        vm.searchQuery = "   "
        #expect(
            snapshot(vm) == VMStateSnapshot(
                state: .loaded(
                    InstalledPackagesContent(
                        formulaRows: [
                            InstalledPackageRow(name: "git", kind: .formula, description: "", installedVersion: "v2.0"),
                            InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1.0"),
                        ],
                        caskRows: [
                            InstalledPackageRow(name: "slack", kind: .cask, description: "", installedVersion: "—"),
                        ],
                    ),
                ),
                formulaRows: [
                    InstalledPackageRow(name: "git", kind: .formula, description: "", installedVersion: "v2.0"),
                    InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1.0"),
                ],
                caskRows: [
                    InstalledPackageRow(name: "slack", kind: .cask, description: "", installedVersion: "—"),
                ],
                selectedPackageID: nil,
                totalPackageCount: 3,
            ),
        )
    }

    @Test @MainActor func `searchQuery didSet with no matches sets loaded state to empty rows`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [InstalledPackageInfo(name: "git", version: "2.0")],
            casks: [InstalledPackageInfo(name: "slack", version: nil)],
        )
        vm.searchQuery = "zzz"
        #expect(
            snapshot(vm) == VMStateSnapshot(
                state: .loaded(InstalledPackagesContent(formulaRows: [], caskRows: [])),
                formulaRows: [],
                caskRows: [],
                selectedPackageID: nil,
                totalPackageCount: 0,
            ),
        )
    }

    @Test @MainActor func `searchQuery didSet does not clear selection when search starts`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [InstalledPackageInfo(name: "git", version: "2.0")],
        )
        guard let selectedID = vm.loadedFormulaRows.first?.id else {
            Issue.record("expected row in loaded state")
            return
        }
        vm.toggleSelection(for: selectedID)
        #expect(vm.selectedPackageID == selectedID)
        #expect(vm.detailsViewModel != nil)

        vm.searchQuery = "g"

        #expect(vm.selectedPackageID == selectedID)
        #expect(vm.detailsViewModel != nil)
    }

    @Test @MainActor func `searchQuery didSet does not clear selection during active search`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                InstalledPackageInfo(name: "git", version: "2.0"),
                InstalledPackageInfo(name: "gh", version: "2.0"),
            ],
        )
        vm.searchQuery = "g"
        guard let selectedID = vm.loadedFormulaRows.first?.id else {
            Issue.record("expected row in filtered loaded state")
            return
        }
        vm.toggleSelection(for: selectedID)
        #expect(vm.selectedPackageID == selectedID)

        vm.searchQuery = "gi"

        #expect(vm.selectedPackageID == selectedID)
    }

    @Test @MainActor func `searchQuery didSet before load keeps loading state`() {
        let vm = InstalledViewModel(
            repository: StubInstalledPackagesRepository(snapshot: .empty),
            detailsRepository: StubPackageDetailsRepository(),
        )
        vm.searchQuery = "git"
        #expect(snapshot(vm) == VMStateSnapshot(state: .loading, formulaRows: [], caskRows: [], selectedPackageID: nil, totalPackageCount: 0))
    }

    @Test @MainActor func `searchQuery didSet after load failure preserves error state`() async {
        let vm = InstalledViewModel(
            repository: StubThrowingRepository(error: OddRepositoryError()),
            detailsRepository: StubPackageDetailsRepository(),
        )
        await vm.load()
        let beforeQuerySnapshot = snapshot(vm)
        vm.searchQuery = "git"
        #expect(snapshot(vm) == beforeQuerySnapshot)
    }

    @Test @MainActor func `searchQuery didSet on empty loaded content remains empty loaded`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel()
        vm.searchQuery = "git"
        #expect(
            snapshot(vm) == VMStateSnapshot(
                state: .loaded(InstalledPackagesContent(formulaRows: [], caskRows: [])),
                formulaRows: [],
                caskRows: [],
                selectedPackageID: nil,
                totalPackageCount: 0,
            ),
        )
    }

    @Test @MainActor func `searchQuery didSet previews top visible row while preserving actual selection`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                InstalledPackageInfo(name: "abc", version: "1.0"),
                InstalledPackageInfo(name: "git", version: "2.0"),
            ],
        )
        guard let selectedID = vm.loadedFormulaRows.last?.id else {
            Issue.record("expected row in loaded state")
            return
        }
        vm.toggleSelection(for: selectedID)
        #expect(vm.detailsViewModel != nil)
        #expect(vm.selectedPackageID == selectedID)

        vm.searchQuery = "a"
        let previewID = vm.loadedFormulaRows.first?.id
        #expect(vm.activeSelectedPackageID == previewID)
        #expect(vm.selectedPackageID == selectedID)
        #expect(vm.detailsViewModel != nil)
    }

    @Test @MainActor func `searchQuery didSet whitespace only query does not hide details`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [InstalledPackageInfo(name: "git", version: "2.0")],
        )
        guard let selectedID = vm.loadedFormulaRows.first?.id else {
            Issue.record("expected row in loaded state")
            return
        }
        vm.toggleSelection(for: selectedID)
        #expect(vm.detailsViewModel != nil)

        vm.searchQuery = "   "
        #expect(vm.detailsViewModel != nil)
        #expect(vm.selectedPackageID == selectedID)
    }

    @Test @MainActor func `searchQuery clear restores pre-search selection when no row click occurred`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                InstalledPackageInfo(name: "abc", version: "1.0"),
                InstalledPackageInfo(name: "git", version: "2.0"),
            ],
        )
        guard let selectedID = vm.loadedFormulaRows.last?.id else {
            Issue.record("expected row in loaded state")
            return
        }
        vm.toggleSelection(for: selectedID)
        vm.searchQuery = "a"
        #expect(vm.activeSelectedPackageID == vm.loadedFormulaRows.first?.id)

        vm.searchQuery = ""

        #expect(vm.selectedPackageID == selectedID)
        #expect(vm.activeSelectedPackageID == selectedID)
    }

    @Test @MainActor func `search row click during search commits selection after clearing query`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                InstalledPackageInfo(name: "abc", version: "1.0"),
                InstalledPackageInfo(name: "git", version: "2.0"),
            ],
        )
        guard let preSearchSelectionID = vm.loadedFormulaRows.last?.id else {
            Issue.record("expected row in loaded state")
            return
        }
        vm.toggleSelection(for: preSearchSelectionID)
        vm.searchQuery = "a"
        guard let clickedRowID = vm.loadedFormulaRows.first?.id else {
            Issue.record("expected row in filtered state")
            return
        }

        vm.toggleSelection(for: clickedRowID)
        vm.searchQuery = ""

        #expect(vm.selectedPackageID == clickedRowID)
        #expect(vm.activeSelectedPackageID == clickedRowID)
    }

    @Test @MainActor func `searchQuery didSet marks search as presented`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [InstalledPackageInfo(name: "git", version: "2.0")],
        )
        #expect(vm.isSearchSelected == false)
        vm.searchQuery = "g"
        #expect(vm.isSearchSelected)
    }
}

private extension InstalledViewModel {
    var loadedFormulaRows: [InstalledPackageRow] {
        guard case let .loaded(content) = state else {
            return []
        }
        return content.formulaRows
    }

    var loadedCaskRows: [InstalledPackageRow] {
        guard case let .loaded(content) = state else {
            return []
        }
        return content.caskRows
    }
}
