//
//  BrewUICell.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// One addressable row of a ``BrewUIList``, found by token identity rather than index or displayed text.
@MainActor
final class BrewUICell: BrewUIElement {
    init(_ app: XCUIApplication, _ id: AXID, in container: XCUIElement? = nil) {
        super.init(app, id, type: .any, in: container)
    }

    /// Rows are tap-gesture targets rather than buttons, so this clicks the row surface itself.
    @discardableResult
    func tap(
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        waitToExist(timeout: timeout, file: file, line: line)
        element.click()
        return self
    }
}
