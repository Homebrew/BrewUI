//
//  InstalledViewModelTopLevelTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import Foundation
import Testing

struct InstalledViewModelTopLevelTests {
    @Test @MainActor func `top level filter defaults to off`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")]),
                .fixture(name: "openssl", kind: .formula),
            ],
            casks: [],
        )

        #expect(!vm.showsTopLevelPackagesOnly)
        #expect(vm.totalPackageCount == 2)
    }

    @Test @MainActor func `top level filter hides packages other installed packages depend on`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")]),
                .fixture(name: "openssl", kind: .formula),
                .fixture(name: "wget", kind: .formula),
            ],
            casks: [.fixture(name: "slack", kind: .cask)],
        )

        vm.showsTopLevelPackagesOnly = true

        // openssl is git's dependency, so it is filtered out; nothing depends on the other rows.
        #expect(vm.loadedFormulaPackages.map(\.name) == ["git", "wget"])
        #expect(vm.loadedCaskPackages.map(\.name) == ["slack"])
        #expect(vm.totalPackageCount == 3)
    }

    @Test @MainActor func `top level filter composes with the scope picker`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")]),
                .fixture(name: "openssl", kind: .formula),
            ],
            casks: [.fixture(name: "slack", kind: .cask, dependencies: [.formula(name: "openssl")])],
        )

        vm.showsTopLevelPackagesOnly = true
        vm.scope = .casks

        // The cask depends on openssl too, so it stays top-level; only casks show.
        #expect(vm.loadedFormulaPackages.isEmpty)
        #expect(vm.loadedCaskPackages.map(\.name) == ["slack"])

        vm.scope = .formulae
        #expect(vm.loadedFormulaPackages.map(\.name) == ["git"])
        #expect(vm.loadedCaskPackages.isEmpty)
    }

    @Test @MainActor func `top level filter composes with the search query`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "openssl", kind: .formula),
                .fixture(name: "ripgrep", kind: .formula, dependencies: [.formula(name: "openssl")]),
            ],
            casks: [],
        )

        vm.searchQuery = "ssl"
        #expect(vm.totalPackageCount == 1)

        // The only "ssl" match is ripgrep's dependency, so the filters together hide everything.
        vm.showsTopLevelPackagesOnly = true
        #expect(vm.totalPackageCount == 0)
    }

    @Test @MainActor func `packageCountSubtitle reflects the top level count`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")]),
                .fixture(name: "openssl", kind: .formula),
                .fixture(name: "wget", kind: .formula),
            ],
            casks: [],
        )

        vm.showsTopLevelPackagesOnly = true
        #expect(vm.packageCountSubtitle == "2 packages")
    }

    @Test @MainActor func `selection falls back to first visible row when the top level filter hides it`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")]),
                .fixture(name: "openssl", kind: .formula),
            ],
            casks: [],
        )
        vm.setSelection(.formula(name: "openssl"))
        #expect(vm.activeSelectedPackageID == .formula(name: "openssl"))

        vm.showsTopLevelPackagesOnly = true
        #expect(vm.activeSelectedPackageID == .formula(name: "git"))
    }

    @Test @MainActor func `disabling the top level filter restores the hidden selection`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")]),
                .fixture(name: "openssl", kind: .formula),
            ],
            casks: [],
        )
        vm.setSelection(.formula(name: "openssl"))

        vm.showsTopLevelPackagesOnly = true
        #expect(vm.activeSelectedPackageID == .formula(name: "git"))

        // The committed selection was never mutated, so widening the filter brings it back.
        vm.showsTopLevelPackagesOnly = false
        #expect(vm.activeSelectedPackageID == .formula(name: "openssl"))
    }

    @Test @MainActor func `top level filter change re-homes the search preview to the first visible row`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "gettext", kind: .formula),
                .fixture(name: "wget", kind: .formula, dependencies: [.formula(name: "gettext")]),
            ],
            casks: [],
        )

        vm.searchQuery = "e"
        // Preview lands on the first matching row: "gettext" sorts before "wget".
        #expect(vm.activeSelectedPackageID == .formula(name: "gettext"))

        vm.showsTopLevelPackagesOnly = true
        // gettext is wget's dependency, so the preview re-homes to the first visible top-level match.
        #expect(vm.activeSelectedPackageID == .formula(name: "wget"))
    }
}
