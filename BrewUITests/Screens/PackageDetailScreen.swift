//
//  PackageDetailScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The right-hand detail column. One type covers the Installed and Discover detail views: they share
/// `AXID.packageDetail` and expose disjoint actions, so the action a test calls decides which is up.
@MainActor
struct PackageDetailScreen: Screen {
    let app: XCUIApplication

    var root: BrewUIElement {
        BrewUIElement(app, .packageDetail)
    }

    var installButton: BrewUIButton {
        BrewUIButton(app, .installButton)
    }

    var uninstallButton: BrewUIButton {
        BrewUIButton(app, .uninstallButton)
    }

    var upgradeButton: BrewUIButton {
        BrewUIButton(app, .upgradeButton)
    }

    /// Returns to Discover: the package only reaches Installed once `brew install` exits and the
    /// inventory reconciles.
    func install(file: StaticString = #filePath, line: UInt = #line) -> DiscoverScreen {
        installButton.tap(file: file, line: line)
        return DiscoverScreen(app: app)
    }

    /// Confirms the destructive dialog, then returns to Installed; the row goes once `brew uninstall`
    /// exits and the repository reconciles.
    ///
    /// The scroll is load-bearing: the default test window height clips the Uninstall button below the
    /// fold, where it exists but is never hittable.
    func uninstall(file: StaticString = #filePath, line: UInt = #line) -> InstalledScreen {
        root.element.scroll(byDeltaX: 0, deltaY: -400)
        uninstallButton.tap(file: file, line: line)
        confirmDestructiveDialog(named: "Uninstall", file: file, line: line)
        return InstalledScreen(app: app)
    }

    func upgrade(file: StaticString = #filePath, line: UInt = #line) -> InstalledScreen {
        upgradeButton.tap(file: file, line: line)
        return InstalledScreen(app: app)
    }

    /// SwiftUI does not forward an identifier onto a `confirmationDialog`, so its buttons go by title,
    /// and whether AppKit reports it as a sheet or a dialog has moved between releases — hence both.
    ///
    /// Scoping to the container matters: the detail pane behind it also has an "Uninstall" button, and
    /// an app-wide query by title could pick that one and silently re-open the dialog.
    private func confirmDestructiveDialog(
        named title: String,
        file: StaticString,
        line: UInt,
    ) {
        let container: XCUIElement
        if app.sheets.firstMatch.waitForExistence(timeout: BrewUITestTimeout.default) {
            container = app.sheets.firstMatch
        } else if app.dialogs.firstMatch.waitForExistence(timeout: BrewUITestTimeout.default) {
            container = app.dialogs.firstMatch
        } else {
            XCTFail("Confirmation dialog did not appear", file: file, line: line)
            return
        }

        let confirm = container.buttons[title]
        XCTAssertTrue(
            confirm.waitForExistence(timeout: BrewUITestTimeout.default),
            "Confirmation dialog has no “\(title)” button",
            file: file,
            line: line,
        )
        confirm.click()
    }
}
