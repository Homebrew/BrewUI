//
//  NavigationUITests.swift
//  BrewUITests
//

import XCTest

/// Every sidebar destination renders. A root that never appears is a crash or a composition mistake.
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
