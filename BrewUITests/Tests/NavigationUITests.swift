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

        installed.sidebar.goToUpgrades()
        installed.sidebar.goToDiscover()
        installed.sidebar.goToServices()
        installed.sidebar.goToDoctor()
        installed.sidebar.goToCleanup()
        installed.sidebar.goToConfiguration()
        installed.sidebar.goToInstalled()
    }

    /// ⌘1–⌘7 follow sidebar order.
    @MainActor
    func testCommandNumbersFollowSidebarOrder() {
        let app = launch(.installedBasic).app
        let destinations: [AXID] = [.installedScreen, .upgradesScreen, .discoverScreen, .servicesScreen, .doctorScreen, .cleanupScreen, .configScreen]
        for (index, destination) in destinations.enumerated() {
            app.typeKey(XCUIKeyboardKey(rawValue: "\(index + 1)"), modifierFlags: .command)
            BrewUIElement(app, destination).assertExists()
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
