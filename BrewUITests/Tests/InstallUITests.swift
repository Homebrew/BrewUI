//
//  InstallUITests.swift
//  BrewUITests
//

import XCTest

/// The widest path in the app: the catalogue arrives over the HTTP seam, the install runs over the
/// shell seam, and the two meet when the inventory reconciles off the completion stream.
final class InstallUITests: BrewUITestCase {
    @MainActor
    func testInstallingFromDiscoverAddsThePackageToInstalled() {
        let installed = launch(.discoverSearch)
        installed.assertDoesNotHavePackage("ripgrep")

        installed.sidebar
            .goToDiscover()
            .search(for: "ripgrep")
            .openDetail(for: "ripgrep")
            .install()
            .console
            .assertOutputContains("Pouring ripgrep")
            .assertSucceeded()

        installed.sidebar
            .goToInstalled()
            .assertHasPackage("ripgrep")
    }

    @MainActor
    func testSearchSurfacesCatalogueMatchesOnly() {
        let installed = launch(.discoverSearch)

        installed.sidebar
            .goToDiscover()
            .search(for: "ripgrep")
            .assertHasPackage("ripgrep")
            .assertDoesNotHavePackage("fd")
    }

    @MainActor
    func testTrendingListsThePackagesAnalyticsRanked() {
        let installed = launch(.discoverSearch)

        installed.sidebar
            .goToDiscover()
            .assertHasPackage("fd")
            .assertHasPackage("iterm2")
    }
}
