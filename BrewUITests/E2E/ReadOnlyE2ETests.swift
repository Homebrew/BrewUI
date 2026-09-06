//
//  ReadOnlyE2ETests.swift
//  BrewUITests
//

import XCTest

/// The canaries that mutate nothing. Doctor is absent and Upgrades goes unasserted because neither
/// has a happy path a live machine can be relied on to produce; both are covered at Tier 2.
final class ReadOnlyE2ETests: BrewE2ETestCase {
    @MainActor
    func testVisitsEverySidebarDestinationAgainstRealData() {
        let installed = launchLive()

        installed.sidebar.goToUpgrades()
        installed.sidebar.goToDiscover()
        installed.sidebar.goToConfiguration()
        installed.sidebar.goToInstalled()
    }

    /// That the row exists is the contract; what it says about `wget` is not.
    @MainActor
    func testSearchFindsAPackageInTheRealCatalogue() {
        launchLive()
            .sidebar
            .goToDiscover()
            .search(for: "wget")
            .assertHasPackage("wget", timeout: BrewE2ETimeout.catalogue)
    }

    /// Keys only: the values are machine-specific by definition.
    @MainActor
    func testConfigurationRendersRealBrewConfigOutput() {
        launchLive()
            .sidebar
            .goToConfiguration()
            .assertShowsEntry("HOMEBREW_VERSION", timeout: BrewE2ETimeout.command)
            .assertShowsEntry("HOMEBREW_PREFIX", timeout: BrewE2ETimeout.command)
    }
}
