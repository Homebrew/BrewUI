//
//  UpgradesViewModelTopLevelTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import Foundation
import Testing

struct UpgradesViewModelTopLevelTests {
    // MARK: - Filtering

    @Test @MainActor func `top level filter hides outdated packages other installed packages depend on`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")], outdated: true),
            .fixture(name: "openssl", kind: .formula, outdated: true),
            .fixture(name: "slack", kind: .cask, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: true),
        ])

        vm.showsTopLevelPackagesOnly = true

        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.packages.map(\.name) == ["git", "slack", "wget"])
        #expect(vm.outdatedCount == 3)
        // The unfiltered total is unaffected by the top-level filter.
        #expect(vm.totalOutdatedCount == 4)
    }

    @Test @MainActor func `dependency edges come from the full inventory not just outdated rows`() {
        // wget is outdated, but the up-to-date htop depends on it — it is still not top-level.
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "htop", kind: .formula, dependencies: [.formula(name: "wget")], outdated: false),
            .fixture(name: "wget", kind: .formula, outdated: true),
        ])

        vm.showsTopLevelPackagesOnly = true

        #expect(vm.outdatedCount == 0)
        #expect(vm.totalOutdatedCount == 1)
    }

    @Test @MainActor func `top level filter composes with the scope picker and the search query`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")], outdated: true),
            .fixture(name: "openssl", kind: .formula, outdated: true),
            .fixture(name: "slack", kind: .cask, outdated: true),
        ])

        vm.showsTopLevelPackagesOnly = true
        vm.scope = .formulae
        vm.searchQuery = "gi"

        guard case let .loaded(content) = vm.state else {
            Issue.record("expected loaded state")
            return
        }
        #expect(content.packages.map(\.name) == ["git"])
        #expect(vm.outdatedCount == 1)
    }

    // MARK: - Subtitle

    @Test @MainActor func `outdatedSubtitle switches to Showing N of M while the top level filter is on`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")], outdated: true),
            .fixture(name: "openssl", kind: .formula, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: true),
        ])

        vm.showsTopLevelPackagesOnly = true

        #expect(vm.outdatedSubtitle == "Showing 2 of 3 upgrades")
    }

    @Test @MainActor func `outdatedSubtitle reports no matches when the top level filter hides everything`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")], outdated: false),
            .fixture(name: "openssl", kind: .formula, outdated: true),
        ])

        vm.showsTopLevelPackagesOnly = true

        #expect(vm.outdatedSubtitle == "No matches in 1 outdated package")
    }

    // MARK: - isFiltering / resetFilters

    @Test @MainActor func `isFiltering reflects the top level filter`() {
        let vm = Self.makeViewModel(packages: Self.outdatedWithDependency)
        #expect(!vm.isFiltering)

        vm.showsTopLevelPackagesOnly = true
        #expect(vm.isFiltering)

        vm.showsTopLevelPackagesOnly = false
        #expect(!vm.isFiltering)
    }

    @Test @MainActor func `resetFilters clears the top level filter alongside scope and search`() {
        let vm = Self.makeViewModel(packages: Self.outdatedWithDependency)
        vm.showsTopLevelPackagesOnly = true
        vm.scope = .casks
        vm.searchQuery = "git"

        vm.resetFilters()

        #expect(!vm.showsTopLevelPackagesOnly)
        #expect(vm.scope == .all)
        #expect(vm.searchQuery.isEmpty)
        #expect(!vm.isFiltering)
    }

    // MARK: - Selection

    @Test @MainActor func `selection falls back and restores across the top level filter`() {
        let vm = Self.makeViewModel(packages: Self.outdatedWithDependency)
        vm.setSelection(.formula(name: "openssl"))
        #expect(vm.activeSelectedPackageID == .formula(name: "openssl"))

        vm.showsTopLevelPackagesOnly = true
        #expect(vm.activeSelectedPackageID == .formula(name: "git"))

        // Committed selection is untouched, so widening the filter restores it.
        vm.showsTopLevelPackagesOnly = false
        #expect(vm.activeSelectedPackageID == .formula(name: "openssl"))
    }

    // MARK: - upgradeSelection

    @Test @MainActor func `upgradeSelection lists the visible top level names`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")], outdated: true),
            .fixture(name: "openssl", kind: .formula, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: true),
        ])

        vm.showsTopLevelPackagesOnly = true

        // brew upgrade cannot express "top-level only", so the visible rows are named explicitly.
        #expect(vm.upgradeSelection == .explicit(["git", "wget"]))
        #expect(vm.bulkUpgradeDisplayCommand == "brew upgrade git wget")
    }

    @Test @MainActor func `upgradeSelection falls back to the scope when the top level filter matches nothing`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")], outdated: false),
            .fixture(name: "openssl", kind: .formula, outdated: true),
        ])

        vm.showsTopLevelPackagesOnly = true

        #expect(vm.upgradeSelection == .all)
        #expect(vm.bulkUpgradeDisplayCommand == "brew upgrade")
    }

    // MARK: - bulkUpgradeSummary

    @Test @MainActor func `bulkUpgradeSummary counts top level packages`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")], outdated: true),
            .fixture(name: "openssl", kind: .formula, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: true),
        ])

        vm.showsTopLevelPackagesOnly = true
        #expect(vm.bulkUpgradeSummary == "Upgrades the 2 top-level packages")

        let single = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")], outdated: true),
            .fixture(name: "openssl", kind: .formula, outdated: true),
        ])

        single.showsTopLevelPackagesOnly = true
        #expect(single.bulkUpgradeSummary == "Upgrades the 1 top-level package")
    }

    @Test @MainActor func `bulkUpgradeSummary keeps the search copy when a search is also active`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")], outdated: true),
            .fixture(name: "openssl", kind: .formula, outdated: true),
            .fixture(name: "wget", kind: .formula, outdated: true),
        ])

        vm.showsTopLevelPackagesOnly = true
        vm.searchQuery = "gi"

        #expect(vm.upgradeSelection == .explicit(["git"]))
        #expect(vm.bulkUpgradeSummary == "Upgrades the 1 package matching your search")
    }

    // MARK: - Empty upgrade action

    @Test @MainActor func `top level filter that hides every upgrade reports the filtered title`() {
        let vm = Self.makeViewModel(packages: [
            .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")], outdated: false),
            .fixture(name: "openssl", kind: .formula, outdated: true),
        ])

        vm.showsTopLevelPackagesOnly = true

        #expect(vm.isFilteringOutEveryUpgrade)
        #expect(vm.emptyUpgradeActionTitle == "Nothing to upgrade here")
    }

    // MARK: - Helpers

    private static var outdatedWithDependency: [InstalledBrewPackage] {
        [
            .fixture(name: "git", kind: .formula, dependencies: [.formula(name: "openssl")], outdated: true),
            .fixture(name: "openssl", kind: .formula, outdated: true),
        ]
    }

    @MainActor
    private static func makeViewModel(packages: [InstalledBrewPackage]) -> UpgradesViewModel {
        UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: packages),
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )
    }
}
