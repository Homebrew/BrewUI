//
//  PackageDetailScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The right-hand detail column, shared by the Installed and Discover detail views, whose actions are
/// disjoint enough that the one a test calls decides which is up.
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

    /// Returns to Discover; the package reaches Installed only once the inventory reconciles.
    func install(file: StaticString = #filePath, line: UInt = #line) -> DiscoverScreen {
        installButton.tap(file: file, line: line)
        return DiscoverScreen(app: app)
    }

    /// Confirms the destructive dialog, then returns to Installed. The scroll is load-bearing: at the
    /// default window height the Uninstall button sits below the fold, where it never becomes hittable.
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

    /// SwiftUI forwards no identifier onto a `confirmationDialog`, and whether AppKit reports it as a
    /// sheet or a dialog has moved between releases. Scoped, or the pane's own button could match.
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
