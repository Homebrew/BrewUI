//
//  BrewUIList.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// A list whose rows are addressed by package token. It is handed the ``AXID`` case that builds a row
/// identifier, so `row("wget")` and the view spell it the same way.
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

    /// Counted by identifier prefix, since SwiftUI's scaffolding makes a child count not a row count.
    /// `List` virtualizes, so this is *rendered* rows and only meaningful for short fixture lists.
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
