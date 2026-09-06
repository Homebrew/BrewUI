//
//  BrewUISearchField.swift
//  BrewUITests
//

import XCTest

/// The one element not addressed by ``AXID``: `.searchable` injects it into the toolbar, where
/// SwiftUI offers no hook to identify it.
@MainActor
final class BrewUISearchField {
    private let app: XCUIApplication

    init(_ app: XCUIApplication) {
        self.app = app
    }

    var element: XCUIElement {
        app.searchFields.firstMatch
    }

    /// Clicks the field, so it proves nothing about ⌘F. ``SearchFocusUITests`` covers that.
    @discardableResult
    func activate(
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        if !element.exists {
            app.typeKey("f", modifierFlags: .command)
        }
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Search field did not appear within \(timeout)s",
            file: file,
            line: line,
        )
        element.click()
        return self
    }

    @discardableResult
    func pressFindShortcut() -> Self {
        app.typeKey("f", modifierFlags: .command)
        return self
    }

    /// At the app, so it reaches whoever holds the keyboard — including nobody.
    @discardableResult
    func pressEscape() -> Self {
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        return self
    }

    /// At the app, not the element: `element.typeText` would focus the field first.
    @discardableResult
    func typeAtCursor(_ text: String) -> Self {
        app.typeText(text)
        return self
    }

    @discardableResult
    func selectAllAtCursor() -> Self {
        app.typeKey("a", modifierFlags: .command)
        return self
    }

    @discardableResult
    func assertValue(
        _ expected: String,
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        let matches = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: matches, object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout),
            .completed,
            "Keystrokes did not reach the search field: wanted \(expected), got \(value)",
            file: file,
            line: line,
        )
        return self
    }

    @discardableResult
    func type(
        _ text: String,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        activate(file: file, line: line)
        element.typeText(text)
        return self
    }

    /// Select-all then delete, so the app's own query-cleared handling runs as it would for a user.
    @discardableResult
    func clear(
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        activate(file: file, line: line)
        app.typeKey("a", modifierFlags: .command)
        element.typeText(XCUIKeyboardKey.delete.rawValue)
        return self
    }

    var value: String {
        element.value as? String ?? ""
    }
}
