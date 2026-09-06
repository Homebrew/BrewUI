//
//  BrewUIButton.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// A control that can be activated. `tap()` keeps the iOS name; macOS clicks underneath.
@MainActor
final class BrewUIButton: BrewUIElement {
    init(_ app: XCUIApplication, _ id: AXID, in container: XCUIElement? = nil) {
        super.init(app, id, type: .any, in: container)
    }

    /// Waits for hittability: a button can exist while off-screen or covered, and clicking one throws.
    @discardableResult
    func tap(
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        waitToBeHittable(timeout: timeout, file: file, line: line)
        element.click()
        return self
    }

    @discardableResult
    func waitToBeHittable(
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        let hittable = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: hittable, object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected \(id.rawValue) to become hittable within \(timeout)s",
            file: file,
            line: line,
        )
        return self
    }

    @discardableResult
    func assertIsEnabled(
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        waitToExist(timeout: timeout, file: file, line: line)
        XCTAssertTrue(element.isEnabled, "Expected \(id.rawValue) to be enabled", file: file, line: line)
        return self
    }

    @discardableResult
    func assertIsDisabled(
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        waitToExist(timeout: timeout, file: file, line: line)
        XCTAssertFalse(element.isEnabled, "Expected \(id.rawValue) to be disabled", file: file, line: line)
        return self
    }
}
