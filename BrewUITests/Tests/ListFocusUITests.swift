//
//  ListFocusUITests.swift
//  BrewUITests
//

import XCTest

/// The list holds the keyboard after a tab switch, asserted through arrow-key navigation because that
/// is what the focus is for: with the keyboard nowhere, the key press opens no detail.
final class ListFocusUITests: BrewUITestCase {
    @MainActor
    func testUpgradesListTakesTheKeyboardWhenSwitchedTo() {
        let upgrades = launch(.installedBasic).sidebar.goToUpgrades()
        upgrades.assertHasPackage("ripgrep")

        upgrades.app.typeKey(.downArrow, modifierFlags: [])

        PackageDetailScreen(app: upgrades.app).waitUntilLoaded()
    }

    @MainActor
    func testInstalledListTakesTheKeyboardWhenSwitchedBackTo() {
        let upgrades = launch(.installedBasic).sidebar.goToUpgrades()
        upgrades.assertHasPackage("ripgrep")

        let installed = upgrades.sidebar.goToInstalled()
        installed.assertHasPackage("wget")

        installed.app.typeKey(.downArrow, modifierFlags: [])

        PackageDetailScreen(app: installed.app).waitUntilLoaded()
    }
}
