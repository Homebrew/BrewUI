//
//  BrewUISearchField.swift
//  BrewUITests
//

import XCTest

/// The toolbar search field, the one element not addressed by ``AXID``: `.searchable` injects it into
/// the toolbar and SwiftUI offers no hook to identify it, so `AXID.installedSearchField` and
/// `.discoverSearchField` stay unattached until the field is a custom view. Element-type matching is
/// confined to this type so the rest of the suite stays identifier-only.
@MainActor
final class BrewUISearchField {
    private let app: XCUIApplication

    init(_ app: XCUIApplication) {
        self.app = app
    }

    var element: XCUIElement {
        app.searchFields.firstMatch
    }

    /// Puts the cursor in the field by clicking it, for callers whose subject is the *search*.
    ///
    /// The trailing click means this proves nothing about ⌘F, whatever the shortcut above it did —
    /// which is how a completely dead ⌘F once kept a green suite. ``SearchFocusUITests`` covers the
    /// shortcut on its own terms; do not reach for this there.
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

    /// Presses ⌘F and returns. No click, no wait, no assertion — a caller testing the shortcut has
    /// to be able to watch it fail.
    @discardableResult
    func pressFindShortcut() -> Self {
        app.typeKey("f", modifierFlags: .command)
        return self
    }

    /// Types at the app, so the text lands only where the cursor already is. `element.typeText`
    /// focuses the element first, which would answer the question the caller is asking.
    @discardableResult
    func typeAtCursor(_ text: String) -> Self {
        app.typeText(text)
        return self
    }

    /// Select-all at the cursor, so a follow-up ``typeAtCursor(_:)`` replaces rather than appends.
    @discardableResult
    func selectAllAtCursor() -> Self {
        app.typeKey("a", modifierFlags: .command)
        return self
    }

    @discardableResult
    func assertValue(
        _ expected: String,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        XCTAssertEqual(
            value,
            expected,
            "Keystrokes did not reach the search field",
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
