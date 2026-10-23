//
//  CleanupScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The Cleanup tab, which previews `brew cleanup` with a dry run before offering to run it.
@MainActor
struct CleanupScreen: Screen {
    let app: XCUIApplication

    var root: BrewUIElement {
        BrewUIElement(app, .cleanupScreen)
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
}
