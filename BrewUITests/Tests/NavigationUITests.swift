//
//  NavigationUITests.swift
//  BrewUITests
//

import XCTest

/// Every sidebar destination reaches a screen that renders. A root that never appears is usually a
/// crash or a composition-root mistake, and is clearer here than inside a feature test.
final class NavigationUITests: BrewUITestCase {
    @MainActor
    func testVisitsEverySidebarDestination() {
        let installed = launch(.installedBasic)

        installed.sidebar.goToUpgrades()
        installed.sidebar.goToDiscover()
        installed.sidebar.goToDoctor()
        installed.sidebar.goToConfiguration()
        installed.sidebar.goToInstalled()
    }

    @MainActor
    func testReturningToADestinationKeepsItLoaded() {
        let installed = launch(.installedBasic)

        installed.sidebar.goToDiscover()
        installed.sidebar
            .goToInstalled()
            .assertHasPackage("wget")
    }
}
