//
//  CleanupScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The Clean Up sheet, opened from Tools › Clean Up…, which previews `brew cleanup` with a dry run
/// before offering to run it.
@MainActor
struct CleanupScreen: Screen {
    let app: XCUIApplication

    var root: BrewUIElement {
        BrewUIElement(app, .cleanupSheet)
    }

    /// Command timeout: rows exist only once `brew cleanup --dry-run` has run and been parsed.
    @discardableResult
    func assertListsItem(
        _ name: String,
        timeout: TimeInterval = BrewUITestTimeout.command,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        BrewUIElement(app, .cleanupRow(name: name), in: root.element).waitToExist(timeout: timeout, file: file, line: line)
        return self
    }

    /// `CleanupReport.placeholder` is not empty, so this exists only once the dry run has found nothing.
    @discardableResult
    func assertIsClean(
        timeout: TimeInterval = BrewUITestTimeout.command,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        BrewUIElement(app, .cleanupEmptyState, in: root.element).waitToExist(timeout: timeout, file: file, line: line)
        return self
    }

    @discardableResult
    func cancel(file: StaticString = #filePath, line: UInt = #line) -> Self {
        BrewUIButton(app, .cleanupCancelButton, in: root.element).tap(file: file, line: line)
        return self
    }

    @discardableResult
    func done(file: StaticString = #filePath, line: UInt = #line) -> Self {
        BrewUIButton(app, .cleanupDoneButton, in: root.element).tap(file: file, line: line)
        return self
    }

    @discardableResult
    func assertIsClosed(file: StaticString = #filePath, line: UInt = #line) -> Self {
        root.assertDoesNotExist(file: file, line: line)
        return self
    }
}

extension Screen {
    /// Tools › Clean Up…, which every main-window screen offers.
    @discardableResult
    func openCleanup(file: StaticString = #filePath, line: UInt = #line) -> CleanupScreen {
        BrewUIMenuItem(app, .toolsCleanupMenuItem).choose(file: file, line: line)
        return CleanupScreen(app: app).waitUntilLoaded(file: file, line: line)
    }
}
