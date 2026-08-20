//
//  ReadOnlyE2ETests.swift
//  BrewUITests
//

import XCTest

/// The canaries that mutate nothing, so they need no isolation of their own.
///
/// Doctor is absent by design: its output is entirely machine-state dependent, so there is no stable
/// happy path to assert. Upgrades is visited but not asserted on, because a live machine cannot be
/// guaranteed a deterministically outdated package. Both are covered at Tier 2.
final class ReadOnlyE2ETests: BrewE2ETestCase {
    @MainActor
    func testVisitsEverySidebarDestinationAgainstRealData() {
        let installed = launchLive()

        installed.sidebar.goToUpgrades()
        installed.sidebar.goToDiscover()
        installed.sidebar.goToConfiguration()
        installed.sidebar.goToInstalled()
    }

    /// That the row exists is the contract — that the catalogue was fetched and decoded. What it says
    /// about `wget` is not.
    @MainActor
    func testSearchFindsAPackageInTheRealCatalogue() {
        launchLive()
            .sidebar
            .goToDiscover()
            .search(for: "wget")
            .assertHasPackage("wget", timeout: BrewE2ETimeout.catalogue)
    }

    /// Keys only, never values: the values are machine-specific by definition, which is why this reads
    /// shape rather than content.
    @MainActor
    func testConfigurationRendersRealBrewConfigOutput() {
        launchLive()
            .sidebar
            .goToConfiguration()
            .assertShowsEntry("HOMEBREW_VERSION", timeout: BrewE2ETimeout.command)
            .assertShowsEntry("HOMEBREW_PREFIX", timeout: BrewE2ETimeout.command)
    }
}
