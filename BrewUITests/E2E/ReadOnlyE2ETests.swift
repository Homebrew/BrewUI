//
//  ReadOnlyE2ETests.swift
//  BrewUITests
//

import XCTest

/// The canaries that mutate nothing, so they need no isolation of their own: navigation, catalogue
/// search, and `brew config` parsing, all against whatever the machine and the network actually say.
///
/// Doctor is absent by design — its output is entirely machine-state dependent, so there is no stable
/// happy path to assert. Upgrades is visited but not asserted on, for the same reason: a live machine
/// cannot be guaranteed to have a deterministically outdated package. Both are covered at Tier 2.
final class ReadOnlyE2ETests: BrewE2ETestCase {
    /// Every destination reaches a screen that renders with real data behind it. A root that never
    /// appears here, when the stubbed suite is green, means production wiring — not a view.
    @MainActor
    func testVisitsEverySidebarDestinationAgainstRealData() {
        let installed = launchLive()

        installed.sidebar.goToUpgrades()
        installed.sidebar.goToDiscover()
        installed.sidebar.goToConfiguration()
        installed.sidebar.goToInstalled()
    }

    /// Proves the real catalogue was fetched and decoded: a row exists for a formula that has been in
    /// Homebrew for decades. That the row exists is the contract; what it says about `wget` is not.
    @MainActor
    func testSearchFindsAPackageInTheRealCatalogue() {
        launchLive()
            .sidebar
            .goToDiscover()
            .search(for: "wget")
            .assertHasPackage("wget", timeout: BrewE2ETimeout.catalogue)
    }

    /// Proves `brew config` output still parses. The keys are asserted, never their values — those are
    /// machine-specific by definition, which is exactly why this reads shape rather than content.
    @MainActor
    func testConfigurationRendersRealBrewConfigOutput() {
        launchLive()
            .sidebar
            .goToConfiguration()
            .assertShowsEntry("HOMEBREW_VERSION", timeout: BrewE2ETimeout.command)
            .assertShowsEntry("HOMEBREW_PREFIX", timeout: BrewE2ETimeout.command)
    }
}
