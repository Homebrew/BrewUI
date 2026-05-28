//
//  InstalledViewModelSearchTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import BrewRepositoriesTestSupport
import BrewRepositoryInterfaces
import BrewServicesTestSupport
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

    @Test @MainActor
    func `searchQuery previews first visible result and restores prior selection when cleared`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", kind: .formula),
                .fixture(name: "wget", kind: .formula),
            ],
            casks: [
                .fixture(name: "github", kind: .cask),
            ],
        )
        vm.setSelection(.formula(name: "wget"))

        vm.searchQuery = "git"
        #expect(vm.activeSelectedPackageID == .formula(name: "git"))
        #expect(vm.selectedPackage?.id == .formula(name: "git"))

        vm.searchQuery = ""
        #expect(vm.activeSelectedPackageID == .formula(name: "wget"))
        #expect(vm.selectedPackage?.id == .formula(name: "wget"))
    }

    @Test @MainActor func `searchQuery commit keeps selected result after clearing search`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", kind: .formula),
                .fixture(name: "wget", kind: .formula),
            ],
            casks: [
                .fixture(name: "github", kind: .cask),
            ],
        )
        vm.setSelection(.formula(name: "wget"))

        vm.searchQuery = "git"
        vm.setSelection(.cask(token: "github"))
        #expect(vm.activeSelectedPackageID == .cask(token: "github"))

        vm.searchQuery = ""
        #expect(vm.activeSelectedPackageID == .cask(token: "github"))
        #expect(vm.selectedPackage?.id == .cask(token: "github"))
    }

    @Test @MainActor
    func `searchQuery updates preview selection as query changes when no selection is committed`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "git", kind: .formula),
                .fixture(name: "wget", kind: .formula),
            ],
            casks: [
                .fixture(name: "github", kind: .cask),
            ],
        )

        vm.searchQuery = "git"
        #expect(vm.activeSelectedPackageID == .formula(name: "git"))

        vm.searchQuery = "github"
        #expect(vm.activeSelectedPackageID == .cask(token: "github"))
        #expect(vm.selectedPackage?.id == .cask(token: "github"))
    }
}
