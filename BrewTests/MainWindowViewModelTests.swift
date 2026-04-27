//
//  MainWindowViewModelTests.swift
//  BrewTests
//

@testable import Brew
import CoreGraphics
import Testing

struct MainWindowViewModelTests {
    @Test @MainActor func `shouldShowInstalledDetailColumn is false with no selected installed package`() {
        let installed = InstalledViewModel(
            testingFormulaRows: [
                InstalledPackageRow(name: "git", kind: .formula, description: "", installedVersion: "v2.0"),
            ],
        )
        installed.selectedPackageID = nil
        let vm = MainWindowViewModel(installedViewModel: installed)
        #expect(vm.shouldShowInstalledDetailColumn == false)
    }

    @Test @MainActor func `shouldShowInstalledDetailColumn is true when installed package is selected`() {
        let row = InstalledPackageRow(name: "git", kind: .formula, description: "", installedVersion: "v2.0")
        let installed = InstalledViewModel(testingFormulaRows: [row])
        installed.selectedPackageID = row.id
        let vm = MainWindowViewModel(installedViewModel: installed)
        #expect(vm.shouldShowInstalledDetailColumn == true)
    }

    @Test @MainActor func `minimumWindowWidth uses two-pane floor when no package selected`() {
        let installed = InstalledViewModel(
            testingFormulaRows: [
                InstalledPackageRow(name: "git", kind: .formula, description: "", installedVersion: "v2.0"),
            ],
        )
        installed.selectedPackageID = nil
        let vm = MainWindowViewModel(installedViewModel: installed)
        let expected = BrewLayout.sidebarWidth + BrewLayout.installedListColumnMinWidth
        #expect(vm.minimumWindowWidth == expected)
    }

    @Test @MainActor func `minimumWindowWidth uses three-pane floor when package selected`() {
        let row = InstalledPackageRow(name: "git", kind: .formula, description: "", installedVersion: "v2.0")
        let installed = InstalledViewModel(testingFormulaRows: [row])
        installed.selectedPackageID = row.id
        let vm = MainWindowViewModel(installedViewModel: installed)
        #expect(vm.shouldShowInstalledDetailColumn)
        #expect(vm.minimumWindowWidth == BrewLayout.installedThreePaneMinWindowWidth)
    }

    @Test @MainActor func `minimumWindowWidth transitions as installed selection changes`() {
        let row = InstalledPackageRow(name: "git", kind: .formula, description: "", installedVersion: "v2.0")
        let installed = InstalledViewModel(testingFormulaRows: [row])
        let vm = MainWindowViewModel(installedViewModel: installed)

        let twoPane = BrewLayout.sidebarWidth + BrewLayout.installedListColumnMinWidth
        let threePane = BrewLayout.installedThreePaneMinWindowWidth

        #expect(!vm.shouldShowInstalledDetailColumn)
        #expect(vm.minimumWindowWidth == twoPane)
        installed.toggleSelection(for: row.id)
        #expect(vm.shouldShowInstalledDetailColumn)
        #expect(vm.minimumWindowWidth == threePane)
        installed.toggleSelection(for: row.id)
        #expect(!vm.shouldShowInstalledDetailColumn)
        #expect(vm.minimumWindowWidth == twoPane)
    }
}
