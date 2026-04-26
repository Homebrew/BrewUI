//
//  InstalledViewModelPresentationTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

private struct SectionVisibilitySnapshot: Equatable {
    var formulae: Bool
    var casks: Bool
}

@MainActor
private func sectionVisibility(_ vm: InstalledViewModel) -> SectionVisibilitySnapshot {
    SectionVisibilitySnapshot(
        formulae: vm.shouldShowFormulaeSection,
        casks: vm.shouldShowCasksSection,
    )
}

struct InstalledViewModelPresentationTests {
    @Test @MainActor func `selectedPackageID is nil for initial no-data state`() {
        let vm = InstalledViewModel()
        #expect(vm.selectedPackageID == nil)
    }

    @Test @MainActor func `shouldShowInitialLoadingIndicator is true when loading with no rows and no error`() {
        let vm = InstalledViewModel(isLoading: true)
        #expect(vm.shouldShowInitialLoadingIndicator)
    }

    @Test @MainActor func `shouldShowInitialLoadingIndicator is false when loading but rows exist`() {
        let vm = InstalledViewModel(
            testingFormulaRows: [
                InstalledPackageRow(name: "a", kind: .formula, description: "", installedVersion: "v1"),
            ],
            isLoading: true,
        )
        #expect(!vm.shouldShowInitialLoadingIndicator)
    }

    @Test @MainActor func `shouldShowInitialLoadingIndicator is false when loading with user error`() {
        let vm = InstalledViewModel(
            isLoading: true,
            userFacingError: "oops",
        )
        #expect(!vm.shouldShowInitialLoadingIndicator)
    }

    @Test @MainActor func `section visibility shows both sections when formulae and casks present`() {
        let vm = InstalledViewModel(
            testingFormulaRows: [
                InstalledPackageRow(name: "f", kind: .formula, description: "", installedVersion: "v1"),
            ],
            testingCaskRows: [
                InstalledPackageRow(name: "c", kind: .cask, description: "", installedVersion: "v1"),
            ],
        )
        #expect(sectionVisibility(vm) == SectionVisibilitySnapshot(formulae: true, casks: true))
    }

    @Test @MainActor func `section visibility shows only formulae when no casks`() {
        let vm = InstalledViewModel(
            testingFormulaRows: [
                InstalledPackageRow(name: "f", kind: .formula, description: "", installedVersion: "v1"),
            ],
        )
        #expect(sectionVisibility(vm) == SectionVisibilitySnapshot(formulae: true, casks: false))
    }

    @Test @MainActor func `section visibility hides all sections when empty`() {
        let vm = InstalledViewModel()
        #expect(sectionVisibility(vm) == SectionVisibilitySnapshot(formulae: false, casks: false))
    }

    @Test @MainActor func `totalPackageCount sums formula and cask rows`() {
        let vm = InstalledViewModel(
            testingFormulaRows: [
                InstalledPackageRow(name: "f", kind: .formula, description: "", installedVersion: "v1"),
            ],
            testingCaskRows: [
                InstalledPackageRow(name: "c", kind: .cask, description: "", installedVersion: "v1"),
            ],
        )
        #expect(vm.totalPackageCount == 2)
    }

    @Test @MainActor func `packageCountSubtitle shows localized loading text when initial loading`() {
        let vm = InstalledViewModel(isLoading: true)
        let expected = String(localized: "Loading packages…", comment: "Installed tab subtitle while fetching")
        #expect(vm.packageCountSubtitle == expected)
    }

    @Test @MainActor func `packageCountSubtitle is singular for one package`() {
        let vm = InstalledViewModel(
            testingFormulaRows: [
                InstalledPackageRow(name: "a", kind: .formula, description: "", installedVersion: "v1"),
            ],
        )
        #expect(vm.packageCountSubtitle == "1 package")
    }

    @Test @MainActor func `packageCountSubtitle is plural for multiple packages`() {
        let vm = InstalledViewModel(
            testingFormulaRows: [
                InstalledPackageRow(name: "a", kind: .formula, description: "", installedVersion: "v1"),
                InstalledPackageRow(name: "b", kind: .formula, description: "", installedVersion: "v1"),
            ],
        )
        #expect(vm.packageCountSubtitle == "2 packages")
    }

    @Test @MainActor func `toggleSelection selects row when nothing selected`() {
        let row = InstalledPackageRow(name: "a", kind: .formula, description: "", installedVersion: "v1")
        let vm = InstalledViewModel(testingFormulaRows: [row])
        vm.toggleSelection(for: row.id)
        #expect(vm.selectedPackageID == row.id)
    }

    @Test @MainActor func `toggleSelection clears selection when tapping selected row`() {
        let row = InstalledPackageRow(name: "a", kind: .formula, description: "", installedVersion: "v1")
        let vm = InstalledViewModel(testingFormulaRows: [row])
        vm.toggleSelection(for: row.id)
        vm.toggleSelection(for: row.id)
        #expect(vm.selectedPackageID == nil)
    }

    @Test @MainActor func `clearSelection clears selected package`() {
        let row = InstalledPackageRow(name: "a", kind: .formula, description: "", installedVersion: "v1")
        let vm = InstalledViewModel(testingFormulaRows: [row])
        vm.selectedPackageID = row.id
        vm.clearSelection()
        #expect(vm.selectedPackageID == nil)
    }
}
