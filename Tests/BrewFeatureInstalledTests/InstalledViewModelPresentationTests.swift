//
//  InstalledViewModelPresentationTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import Foundation
import Testing

struct InstalledViewModelPresentationTests {
    @Test @MainActor func `selectedPackage is nil for initial loading state`() {
        let vm = makeInstalledViewModel(
            repository: unloadedInstalledRepository(),
        )
        #expect(vm.selectedPackage == nil)
    }

    @Test @MainActor func `shouldShowInitialLoadingIndicator is true when loading with no rows and no error`() {
        let vm = makeInstalledViewModel(
            repository: unloadedInstalledRepository(),
        )
        #expect(vm.shouldShowInitialLoadingIndicator)
    }

    @Test @MainActor func `shouldShowInitialLoadingIndicator is false after successful load`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "a", kind: .formula)],
        )
        #expect(!vm.shouldShowInitialLoadingIndicator)
    }

    @Test @MainActor func `shouldShowInitialLoadingIndicator is false when load has user error`() async {
        let vm = makeInstalledViewModel(repository: missingBrewInstalledRepository())
        await vm.load()
        #expect(!vm.shouldShowInitialLoadingIndicator)
    }

    @Test @MainActor func `totalPackageCount sums formula and cask rows`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "f", kind: .formula)],
            casks: [.fixture(name: "c", kind: .cask)],
        )
        #expect(vm.totalPackageCount == 2)
    }

    @Test @MainActor func `packageCountSubtitle shows localized loading text when initial loading`() {
        let vm = makeInstalledViewModel(
            repository: unloadedInstalledRepository(),
        )
        let expected = String(localized: "Loading packages…", comment: "Installed tab subtitle while fetching")
        #expect(vm.packageCountSubtitle == expected)
    }

    @Test @MainActor func `packageCountSubtitle is singular for one package`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "a", kind: .formula)],
        )
        #expect(vm.packageCountSubtitle == "1 package")
    }

    @Test @MainActor func `packageCountSubtitle is plural for multiple packages`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "a", kind: .formula),
                .fixture(name: "b", kind: .formula),
            ],
        )
        #expect(vm.packageCountSubtitle == "2 packages")
    }

    @Test @MainActor func `setSelection selects row when nothing selected`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "a", kind: .formula)],
        )
        guard let row = selectedFormulaRow(from: vm) else {
            Issue.record("expected row in loaded state")
            return
        }
        vm.setSelection(row.id)
        #expect(vm.selectedPackage?.id == row.id)
    }

    @Test @MainActor func `setSelection nil on sole selected row resolves to first visible row`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "a", kind: .formula)],
        )
        guard let row = selectedFormulaRow(from: vm) else {
            Issue.record("expected row in loaded state")
            return
        }
        vm.setSelection(row.id)
        vm.setSelection(nil)
        #expect(vm.selectedPackage?.id == row.id)
    }

    @Test @MainActor func `clearSelection resets to first visible row`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "a", kind: .formula)],
        )
        guard let row = selectedFormulaRow(from: vm) else {
            Issue.record("expected row in loaded state")
            return
        }
        vm.setSelection(row.id)
        vm.clearSelection()
        #expect(vm.selectedPackage?.id == row.id)
    }
}

@MainActor
private func selectedFormulaRow(from vm: InstalledViewModel) -> InstalledBrewPackage? {
    guard case let .loaded(content) = vm.state else {
        return nil
    }
    return content.formulaPackages.first
}
