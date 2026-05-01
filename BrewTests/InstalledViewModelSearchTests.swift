//
//  InstalledViewModelSearchTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct InstalledViewModelSearchTests {
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
        let gitFormula = InstalledPackageRow(
            name: "Git",
            kind: .formula,
            description: "",
            installedVersion: "v2.0",
        )
        let githubCask = InstalledPackageRow(
            name: "GitHub",
            kind: .cask,
            description: "",
            installedVersion: "—",
        )
        #expect(
            snapshot(vm) == VMStateSnapshot(
                state: .loaded(
                    InstalledPackagesContent(
                        formulaRows: [gitFormula],
                        caskRows: [githubCask],
                    ),
                ),
                formulaRows: [gitFormula],
                caskRows: [githubCask],
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
        let gitRow = InstalledPackageRow(
            name: "git",
            kind: .formula,
            description: "",
            installedVersion: "v2.0",
        )
        let wgetRow = InstalledPackageRow(
            name: "wget",
            kind: .formula,
            description: "",
            installedVersion: "v1.0",
        )
        let slackRow = InstalledPackageRow(
            name: "slack",
            kind: .cask,
            description: "",
            installedVersion: "—",
        )
        #expect(
            snapshot(vm) == VMStateSnapshot(
                state: .loaded(
                    InstalledPackagesContent(
                        formulaRows: [gitRow, wgetRow],
                        caskRows: [slackRow],
                    ),
                ),
                formulaRows: [gitRow, wgetRow],
                caskRows: [slackRow],
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
        #expect(
            snapshot(vm)
                == VMStateSnapshot(
                    state: .loading,
                    formulaRows: [],
                    caskRows: [],
                    selectedPackageID: nil,
                    totalPackageCount: 0,
                ),
        )
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
}

// MARK: - Selection, preview, and details

struct InstalledViewModelSearchSelectionTests {
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

    @Test @MainActor func `searchQuery typing keeps same details VM when active selection unchanged`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                InstalledPackageInfo(name: "alpha", version: "1.0"),
                InstalledPackageInfo(name: "alpine", version: "1.0"),
                InstalledPackageInfo(name: "zeta", version: "1.0"),
            ],
        )
        guard let preSearchSelectionID = vm.loadedFormulaRows.last?.id else {
            Issue.record("expected row in loaded state")
            return
        }
        vm.toggleSelection(for: preSearchSelectionID)

        vm.searchQuery = "a"
        guard let firstSearchDetailsViewModel = vm.detailsViewModel else {
            Issue.record("expected details view model after search starts")
            return
        }

        vm.searchQuery = "al"
        guard let secondSearchDetailsViewModel = vm.detailsViewModel else {
            Issue.record("expected details view model while searching")
            return
        }

        #expect(ObjectIdentifier(firstSearchDetailsViewModel) == ObjectIdentifier(secondSearchDetailsViewModel))
    }

    @Test @MainActor func `searchQuery typing replaces details VM when active selection changes`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                InstalledPackageInfo(name: "alpha", version: "1.0"),
                InstalledPackageInfo(name: "alpine", version: "1.0"),
                InstalledPackageInfo(name: "zeta", version: "1.0"),
            ],
        )
        guard let preSearchSelectionID = vm.loadedFormulaRows.last?.id else {
            Issue.record("expected row in loaded state")
            return
        }
        vm.toggleSelection(for: preSearchSelectionID)

        vm.searchQuery = "a"
        guard let firstSearchDetailsViewModel = vm.detailsViewModel else {
            Issue.record("expected details view model after search starts")
            return
        }

        vm.searchQuery = "alpi"
        guard let secondSearchDetailsViewModel = vm.detailsViewModel else {
            Issue.record("expected details view model after active selection changes")
            return
        }

        #expect(ObjectIdentifier(firstSearchDetailsViewModel) != ObjectIdentifier(secondSearchDetailsViewModel))
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
