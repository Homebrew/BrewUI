//
//  SearchFocusUITests.swift
//  BrewUITests
//

import XCTest

/// ⌘F on each searchable tab. Nothing here may click the search field.
final class SearchFocusUITests: BrewUITestCase {
    // MARK: - Installed

    @MainActor
    func testCommandFFocusesInstalledSearchField() {
        let installed = launch(.installedBasic)

        installed.searchField
            .pressFindShortcut()
            .typeAtCursor("wget")
            .assertValue("wget")

        installed
            .assertHasPackage("wget")
            .assertDoesNotHavePackage("iterm2")
    }

    @MainActor
    func testCommandFRefocusesInstalledSearchFieldAfterCursorLeaves() {
        let installed = launch(.installedBasic)

        installed.searchField
            .pressFindShortcut()
            .typeAtCursor("wget")
        installed.assertDoesNotHavePackage("iterm2")

        installed.list.row("wget").tap()

        installed.searchField
            .pressFindShortcut()
            .selectAllAtCursor()
            .typeAtCursor("iterm2")
            .assertValue("iterm2")

        installed.assertHasPackage("iterm2")
    }

    // MARK: - Upgrades

    @MainActor
    func testCommandFFocusesUpgradesSearchField() {
        let upgrades = launch(.installedBasic).sidebar.goToUpgrades()
        upgrades.assertHasPackage("ripgrep")

        upgrades.searchField
            .pressFindShortcut()
            .typeAtCursor("rip")
            .assertValue("rip")

        upgrades.assertHasPackage("ripgrep")
    }

    @MainActor
    func testCommandFRefocusesUpgradesSearchFieldAfterCursorLeaves() {
        let upgrades = launch(.installedBasic).sidebar.goToUpgrades()
        upgrades.assertHasPackage("ripgrep")

        upgrades.searchField
            .pressFindShortcut()
            .typeAtCursor("rip")
            .assertValue("rip")

        upgrades.list.row("ripgrep").tap()

        upgrades.searchField
            .pressFindShortcut()
            .selectAllAtCursor()
            .typeAtCursor("ripgrep")
            .assertValue("ripgrep")

        upgrades.assertHasPackage("ripgrep")
    }

    // MARK: - Discover

    @MainActor
    func testCommandFFocusesDiscoverSearchField() {
        let discover = launch(.discoverSearch).sidebar.goToDiscover()

        discover.searchField
            .pressFindShortcut()
            .typeAtCursor("ripgrep")
            .assertValue("ripgrep")

        discover
            .assertHasPackage("ripgrep")
            .assertDoesNotHavePackage("fd")
    }

    @MainActor
    func testCommandFRefocusesDiscoverSearchFieldAfterCursorLeaves() {
        let discover = launch(.discoverSearch).sidebar.goToDiscover()

        discover.searchField
            .pressFindShortcut()
            .typeAtCursor("ripgrep")
        discover.assertHasPackage("ripgrep")

        discover.list.row("ripgrep").tap()

        discover.searchField
            .pressFindShortcut()
            .selectAllAtCursor()
            .typeAtCursor("fd")
            .assertValue("fd")

        discover.assertHasPackage("fd")
    }

    // MARK: - Tab switching

    @MainActor
    func testCommandFReachesBothTabsSharingOneSearchField() {
        let installed = launch(.installedBasic)

        installed.searchField
            .pressFindShortcut()
            .typeAtCursor("wget")
            .assertValue("wget")

        let upgrades = installed.sidebar.goToUpgrades()
        upgrades.searchField
            .pressFindShortcut()
            .selectAllAtCursor()
            .typeAtCursor("rip")
            .assertValue("rip")
        upgrades.assertHasPackage("ripgrep")

        let backToInstalled = upgrades.sidebar.goToInstalled()
        backToInstalled.searchField
            .pressFindShortcut()
            .selectAllAtCursor()
            .typeAtCursor("iterm2")
            .assertValue("iterm2")
        backToInstalled.assertHasPackage("iterm2")
    }
}
