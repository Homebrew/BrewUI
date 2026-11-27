//
//  BrewUIMenuItem.swift
//  BrewUITests
//

import XCTest

/// A menu bar command. SwiftUI does not pass an accessibility identifier from a `Commands` button to its
/// menu item, so this one is found by its English titles; ``BrewApp/launch(scenario:environment:)`` pins
/// the app to English.
@MainActor
struct BrewUIMenuItem {
    let app: XCUIApplication
    let menu: String
    let item: String

    private var element: XCUIElement {
        app.menuBarItems[menu].menuItems[item]
    }

    /// Opens the menu, then waits for the item to be enabled, since a command is disabled until a main
    /// window has focus.
    func choose(
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) {
        app.menuBarItems[menu].click()
        let enabled = NSPredicate(format: "exists == true AND isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: enabled, object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected \(menu) › \(item) to be enabled within \(timeout)s\n\(BrewUITestDiagnostics.report(for: app))",
            file: file,
            line: line,
        )
        element.click()
    }
}
