//
//  BrewUIStaticText.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// Read-only text, asserted through ``effectiveText`` rather than the raw accessibility label.
@MainActor
final class BrewUIStaticText: BrewUIElement {
    init(_ app: XCUIApplication, _ id: AXID, in container: XCUIElement? = nil) {
        super.init(app, id, type: .any, in: container)
    }

    var label: String {
        element.label
    }

    /// What VoiceOver would read. On macOS a combined element's `Text` children populate the
    /// accessibility *value*, and `label` stays empty unless set explicitly.
    private var effectiveText: String {
        let label = element.label
        guard label.isEmpty else {
            return label
        }
        return element.value as? String ?? ""
    }

    @discardableResult
    func assertContains(
        _ substring: String,
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        // Poll: the text usually arrives a render or two after the element does.
        let predicate = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", substring, substring)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected \(id.rawValue) to contain “\(substring)” within \(timeout)s, got “\(effectiveText)”",
            file: file,
            line: line,
        )
        return self
    }

    @discardableResult
    func assertDoesNotContain(
        _ substring: String,
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        waitToExist(timeout: timeout, file: file, line: line)
        XCTAssertFalse(
            effectiveText.contains(substring),
            "Expected \(id.rawValue) not to contain “\(substring)”, got “\(effectiveText)”",
            file: file,
            line: line,
        )
        return self
    }
}
