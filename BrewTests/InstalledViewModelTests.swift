//
//  InstalledViewModelTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct InstalledViewModelTests {
    @Test @MainActor func `load produces expected package sections`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
            casks: [.fixture(name: "slack", kind: .cask)],
        )
        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.formulaPackages.count == 1)
        #expect(content.caskPackages.count == 1)
        #expect(vm.totalPackageCount == 2)
    }

    @Test @MainActor func `toggleSelection updates selected package`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
        )
        guard let selectedID = vm.loadedFormulaPackages.first?.id else { return }
        vm.toggleSelection(for: selectedID)
        #expect(vm.selectedPackage?.id == selectedID)
    }

    @Test @MainActor func `clearSelection clears selected package`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
        )
        guard let selectedID = vm.loadedFormulaPackages.first?.id else { return }
        vm.toggleSelection(for: selectedID)
        vm.clearSelection()
        #expect(vm.selectedPackage == nil)
    }
}
