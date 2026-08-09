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

    /// Opens the search field via ⌘F (`SearchCommands`) and waits for it to take focus.
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
