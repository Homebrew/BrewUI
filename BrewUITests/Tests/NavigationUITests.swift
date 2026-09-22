//
//  NavigationUITests.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// Every sidebar destination renders. A root that never appears is a crash or a composition mistake.
final class NavigationUITests: BrewUITestCase {
    @MainActor
    func testVisitsEverySidebarDestination() {
        let installed = launch(.installedBasic)

        BrewUIButton(installed.app, .sidebarItem(.services)).tap()
        BrewUIElement(installed.app, .servicesScreen).assertExists()

        installed.sidebar.goToUpgrades()
        installed.sidebar.goToDiscover()
        installed.sidebar.goToDoctor()
        installed.sidebar.goToConfiguration()
        installed.sidebar.goToInstalled()
        let destinations: [AXID] = [.installedScreen, .servicesScreen, .upgradesScreen, .discoverScreen, .doctorScreen, .configScreen]
        for (index, destination) in destinations.enumerated() {
            installed.app.typeKey(XCUIKeyboardKey(rawValue: "\(index + 1)"), modifierFlags: .command)
            BrewUIElement(installed.app, destination).assertExists()
        }
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
