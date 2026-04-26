//
//  MainWindowViewModelTests.swift
//  BrewTests
//

@testable import Brew
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
}
