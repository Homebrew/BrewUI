//
//  SearchFocusUITests.swift
//  BrewUITests
//

import XCTest

/// ⌘F on each searchable tab, driven by keyboard alone.
///
/// Every assertion here is that typed characters landed *in the field*, never that the field looks
/// focused: the shortcut's whole job is to move the cursor, and only text arriving proves it moved.
/// Nothing in this file may click the search field — see ``BrewUISearchField/activate(timeout:file:line:)``.
///
/// The re-focus cases are the regression. ⌘F used to write `true` into a presentation binding that
/// was already `true` once the field had been shown, so the second press onwards did nothing at all.
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

        // Moves the cursor out while leaving the field on screen and populated — the state the old
        // presentation binding could not tell apart from "the user is still typing".
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

        upgrades.searchField
            .pressFindShortcut()
            .typeAtCursor("zzz")
            .assertValue("zzz")

        upgrades.assertDoesNotHavePackage("ripgrep")
    }

    @MainActor
    func testCommandFRefocusesUpgradesSearchFieldAfterCursorLeaves() {
        let upgrades = launch(.installedBasic).sidebar.goToUpgrades()

        upgrades.searchField
            .pressFindShortcut()
            .typeAtCursor("rip")
        upgrades.assertHasPackage("ripgrep")

        upgrades.list.row("ripgrep").tap()

        upgrades.searchField
            .pressFindShortcut()
            .selectAllAtCursor()
            .typeAtCursor("zzz")
            .assertValue("zzz")

        upgrades.assertDoesNotHavePackage("ripgrep")
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

    /// The Installed and Upgrades tabs share one `.searchable`, re-routed per tab. ⌘F has to keep
    /// reaching whichever one is on screen, and the query it lands in has to be that tab's own.
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
