//
//  InstalledViewModelScopeTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import Foundation
import Testing

struct InstalledViewModelScopeTests {
    @Test @MainActor func `scope defaults to all and shows both kinds`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
            casks: [.fixture(name: "slack", kind: .cask)],
        )

        #expect(vm.scope == .all)
        #expect(vm.loadedFormulaPackages.map(\.name) == ["git"])
        #expect(vm.loadedCaskPackages.map(\.name) == ["slack"])
        #expect(vm.totalPackageCount == 2)
    }

    @Test @MainActor func `scope formulae hides casks`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", kind: .formula),
                .fixture(name: "wget", kind: .formula),
            ],
            casks: [.fixture(name: "slack", kind: .cask)],
        )

        vm.scope = .formulae

        #expect(vm.loadedFormulaPackages.map(\.name) == ["git", "wget"])
        #expect(vm.loadedCaskPackages.isEmpty)
        #expect(vm.totalPackageCount == 2)
    }

    @Test @MainActor func `scope casks hides formulae`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
            casks: [
                .fixture(name: "slack", kind: .cask),
                .fixture(name: "docker", kind: .cask),
            ],
        )

        vm.scope = .casks

        #expect(vm.loadedFormulaPackages.isEmpty)
        #expect(vm.loadedCaskPackages.map(\.name) == ["slack", "docker"])
        #expect(vm.totalPackageCount == 2)
    }

    @Test @MainActor func `scope composes with the search query`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", kind: .formula),
                .fixture(name: "wget", kind: .formula),
            ],
            casks: [.fixture(name: "github", kind: .cask)],
        )

        vm.scope = .formulae
        vm.searchQuery = "git"

        // The cask "github" matches the query but is excluded by the formulae scope.
        #expect(vm.loadedFormulaPackages.map(\.name) == ["git"])
        #expect(vm.loadedCaskPackages.isEmpty)
    }

    @Test @MainActor func `packageCountSubtitle reflects the scoped count`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
            casks: [
                .fixture(name: "slack", kind: .cask),
                .fixture(name: "docker", kind: .cask),
            ],
        )

        vm.scope = .formulae
        #expect(vm.packageCountSubtitle == "1 package")

        vm.scope = .casks
        #expect(vm.packageCountSubtitle == "2 packages")
    }

    @Test @MainActor func `selection falls back to first visible row when scope hides it`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
            casks: [.fixture(name: "slack", kind: .cask)],
        )
        vm.setSelection(.cask(token: "slack"))
        #expect(vm.activeSelectedPackageID == .cask(token: "slack"))

        // Scoping to formulae hides the selected cask; the always-on selection falls back to the
        // first visible formula.
        vm.scope = .formulae
        #expect(vm.activeSelectedPackageID == .formula(name: "git"))
    }

    @Test @MainActor func `widening scope restores the previously scoped-out selection`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "git", kind: .formula)],
            casks: [.fixture(name: "slack", kind: .cask)],
        )
        vm.setSelection(.cask(token: "slack"))

        vm.scope = .formulae
        #expect(vm.activeSelectedPackageID == .formula(name: "git"))

        // The committed cask selection was never mutated, so widening the scope brings it back.
        vm.scope = .all
        #expect(vm.activeSelectedPackageID == .cask(token: "slack"))
    }

    @Test @MainActor func `scope change re-homes the search preview to the first visible row`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "gitui", kind: .formula)],
            casks: [.fixture(name: "github", kind: .cask)],
        )

        vm.searchQuery = "git"
        // Preview lands on the first visible row across both kinds (formula first).
        #expect(vm.activeSelectedPackageID == .formula(name: "gitui"))

        vm.scope = .casks
        // With formulae scoped out, the preview re-homes to the first visible cask.
        #expect(vm.activeSelectedPackageID == .cask(token: "github"))
    }
}
