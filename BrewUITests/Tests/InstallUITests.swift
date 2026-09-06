//
//  InstallUITests.swift
//  BrewUITests
//

import XCTest

/// The widest path in the app: catalogue over the HTTP seam, install over the shell seam, and the two
/// meeting when the inventory reconciles.
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
