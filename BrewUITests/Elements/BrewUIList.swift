//
//  BrewUIList.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// A list whose rows are addressed by package token, through the ``AXID`` case the view spells.
@MainActor
final class BrewUIList: BrewUIElement {
    private let rowID: @Sendable (String) -> AXID

    init(
        _ app: XCUIApplication,
        _ id: AXID,
        rowID: @escaping @Sendable (String) -> AXID,
        in container: XCUIElement? = nil,
    ) {
        self.rowID = rowID
        super.init(app, id, type: .any, in: container)
    }

    func row(_ token: String) -> BrewUICell {
        BrewUICell(app, rowID(token))
    }

    /// Rendered rows only, since `List` virtualizes: meaningful for fixtures, not a real inventory.
    var count: Int {
        let prefix = rowID("").rawValue
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", prefix)
        return app.descendants(matching: .any).matching(predicate).count
    }

    @discardableResult
    func assertCount(
        _ expected: Int,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        XCTAssertEqual(count, expected, "Unexpected row count in \(id.rawValue)", file: file, line: line)
        return self
    }
}
