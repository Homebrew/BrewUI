//
//  SearchDismissUITests.swift
//  BrewUITests
//

import XCTest

/// Escape out of the search field. Unlike ``SearchFocusUITests`` these do click it: dismissal is what
/// used to wedge the app, and only a click puts the cursor there without going through ⌘F first.
final class SearchDismissUITests: BrewUITestCase {
    @MainActor
    func testEscapeFromSearchFieldLeavesTheAppResponsive() {
        let installed = launch(.installedBasic)

        installed.searchField.activate()
        installed.searchField.pressEscape()

        // A wedged app answers no queries at all, so reaching a row is the assertion.
        installed
            .assertHasPackage("wget")
            .assertHasPackage("iterm2")
    }

    /// The keyboard has to land somewhere on the way out, or arrow-key navigation is dead afterwards.
    @MainActor
    func testEscapeHandsTheKeyboardBackToTheList() {
        let installed = launch(.installedBasic)

        installed.searchField
            .activate()
            .typeAtCursor("wget")
            .assertValue("wget")
        installed.searchField.pressEscape()

        installed.searchField
            .pressFindShortcut()
            .selectAllAtCursor()
            .typeAtCursor("iterm2")
            .assertValue("iterm2")

        installed.assertHasPackage("iterm2")
    }

    @MainActor
    func testRepeatedEscapesLeaveTheAppResponsive() {
        let installed = launch(.installedBasic)

        for _ in 0 ..< 3 {
            installed.searchField.activate()
            installed.searchField.pressEscape()
            installed.searchField.pressEscape()
        }

        installed.assertHasPackage("wget")
    }
}
