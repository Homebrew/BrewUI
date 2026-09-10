//
//  InstalledViewModelHideDependenciesTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import Foundation
import Testing

struct InstalledViewModelHideDependenciesTests {
    @Test @MainActor func `hideDependencies defaults to false and includes dependencies`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", installedOnRequest: true),
                .fixture(name: "pcre2", installedOnRequest: false),
            ],
            casks: [
                .fixture(name: "slack", kind: .cask, installedOnRequest: true),
            ],
        )

        #expect(vm.hideDependencies == false)
        #expect(vm.loadedFormulaPackages.map(\.name) == ["git", "pcre2"])
        #expect(vm.loadedCaskPackages.map(\.name) == ["slack"])
        #expect(vm.totalPackageCount == 3)
        #expect(vm.packageCountSubtitle == "3 packages")
    }

    @Test @MainActor func `hideDependencies true filters out packages installed as dependencies`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", installedOnRequest: true),
                .fixture(name: "pcre2", installedOnRequest: false),
            ],
            casks: [
                .fixture(name: "slack", kind: .cask, installedOnRequest: true),
                .fixture(name: "font-dep", kind: .cask, installedOnRequest: false),
            ],
        )

        vm.hideDependencies = true

        #expect(vm.loadedFormulaPackages.map(\.name) == ["git"])
        #expect(vm.loadedCaskPackages.map(\.name) == ["slack"])
        #expect(vm.totalPackageCount == 2)
        #expect(vm.packageCountSubtitle == "2 packages")
    }

    @Test @MainActor func `hideDependencies composes with scope`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", installedOnRequest: true),
                .fixture(name: "pcre2", installedOnRequest: false),
            ],
            casks: [
                .fixture(name: "slack", kind: .cask, installedOnRequest: true),
            ],
        )

        vm.hideDependencies = true
        vm.scope = .formulae

        #expect(vm.loadedFormulaPackages.map(\.name) == ["git"])
        #expect(vm.loadedCaskPackages.isEmpty)
        #expect(vm.totalPackageCount == 1)
        #expect(vm.packageCountSubtitle == "1 package")
    }

    @Test @MainActor func `hideDependencies composes with search query`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "openssl@3", installedOnRequest: true),
                .fixture(name: "openssl-dep", installedOnRequest: false),
            ],
        )

        vm.searchQuery = "openssl"
        #expect(vm.loadedFormulaPackages.map(\.name) == ["openssl@3", "openssl-dep"])

        vm.hideDependencies = true
        #expect(vm.loadedFormulaPackages.map(\.name) == ["openssl@3"])
    }

    @Test @MainActor func `selection falls back to first visible row when hideDependencies hides it`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", installedOnRequest: true),
                .fixture(name: "pcre2", installedOnRequest: false),
            ],
        )
        vm.setSelection(.formula(name: "pcre2"))
        #expect(vm.activeSelectedPackageID == .formula(name: "pcre2"))

        // Hiding dependencies hides pcre2; selection falls back to the first visible package.
        vm.hideDependencies = true
        #expect(vm.activeSelectedPackageID == .formula(name: "git"))
    }

    @Test @MainActor func `unchecking hideDependencies restores the previously hidden selection`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", installedOnRequest: true),
                .fixture(name: "pcre2", installedOnRequest: false),
            ],
        )
        vm.setSelection(.formula(name: "pcre2"))

        vm.hideDependencies = true
        #expect(vm.activeSelectedPackageID == .formula(name: "git"))

        // The committed selection was not discarded, so clearing the filter restores it.
        vm.hideDependencies = false
        #expect(vm.activeSelectedPackageID == .formula(name: "pcre2"))
    }

    @Test @MainActor func `hideDependencies change re-homes the search preview to the first visible row`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "libuv", installedOnRequest: false),
                .fixture(name: "libusb", installedOnRequest: true),
            ],
        )

        vm.searchQuery = "lib"
        #expect(vm.activeSelectedPackageID == .formula(name: "libuv"))

        vm.hideDependencies = true
        #expect(vm.activeSelectedPackageID == .formula(name: "libusb"))
    }
}
