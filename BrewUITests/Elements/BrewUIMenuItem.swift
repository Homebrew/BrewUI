//
//  BrewUIMenuItem.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// A menu bar command, found by identifier rather than its title so the test survives a reworded menu.
@MainActor
final class BrewUIMenuItem: BrewUIElement {
    init(_ app: XCUIApplication, _ id: AXID) {
        super.init(app, id, type: .menuItem)
    }

    /// macOS opens the enclosing menu itself, and a closed menu's items are never hittable, so this waits
    /// for the item to exist and be enabled rather than for hittability.
    @discardableResult
    func choose(
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        waitToExist(timeout: timeout, file: file, line: line)
        let enabled = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: enabled, object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected \(id.rawValue) to become enabled within \(timeout)s",
            file: file,
            line: line,
        )
        element.click()
        return self
    }
}
