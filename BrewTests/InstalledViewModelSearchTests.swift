//
//  InstalledViewModelSearchTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct InstalledViewModelSearchTests {
    @Test @MainActor func `searchQuery filters loaded formula and cask packages case insensitively`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "Git", kind: .formula),
                .fixture(name: "wget", kind: .formula),
            ],
            casks: [
                .fixture(name: "GitHub", kind: .cask),
                .fixture(name: "Slack", kind: .cask),
            ],
        )
        vm.searchQuery = "git"
        #expect(vm.loadedFormulaPackages.map(\.name) == ["Git"])
        #expect(vm.loadedCaskPackages.map(\.name) == ["GitHub"])
    }

    @Test @MainActor func `searchQuery whitespace restores all loaded packages`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", kind: .formula),
                .fixture(name: "wget", kind: .formula),
            ],
            casks: [
                .fixture(name: "slack", kind: .cask),
            ],
        )
        vm.searchQuery = "git"
        vm.searchQuery = "   "
        #expect(vm.loadedFormulaPackages.count == 2)
        #expect(vm.loadedCaskPackages.count == 1)
    }

    @Test @MainActor func `searchQuery with no matches sets loaded state to empty packages`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
            casks: [.fixture(name: "slack", kind: .cask)],
        )
        vm.searchQuery = "zzz"
        #expect(vm.loadedFormulaPackages.isEmpty)
        #expect(vm.loadedCaskPackages.isEmpty)
    }
}
