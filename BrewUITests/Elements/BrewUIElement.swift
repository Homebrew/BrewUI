//
//  BrewUIElement.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The only layer in the suite that touches `XCUIElement`, addressing elements only by ``AXID``.
///
/// Two rules are enforced here rather than remembered at every call site: every operation self-waits,
/// because a bare `exists` read races the app's next render and is the largest source of XCUITest
/// flake; and failures carry the caller's `file`/`line`, so a red test points at the test body.
@MainActor
class BrewUIElement {
    let app: XCUIApplication
    let id: AXID
    let type: XCUIElement.ElementType

    /// Pass a screen's element to disambiguate chrome several screens share, such as the error state.
    private let container: XCUIElement

    init(
        _ app: XCUIApplication,
        _ id: AXID,
        type: XCUIElement.ElementType = .any,
        in container: XCUIElement? = nil,
    ) {
        self.app = app
        self.id = id
        self.type = type
        self.container = container ?? app
    }

    /// Resolved fresh each access: `XCUIElement` is a live query, so a held one goes stale.
    var element: XCUIElement {
        container.descendants(matching: type)[id.rawValue]
    }

    @discardableResult
    func waitToExist(
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        guard element.waitForExistence(timeout: timeout) else {
            XCTFail(
                """
                Expected \(id.rawValue) to exist within \(timeout)s.
                \(BrewUITestDiagnostics.report(for: app))
                """,
                file: file,
                line: line,
            )
            return self
        }
        return self
    }

    @discardableResult
    func assertExists(
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        waitToExist(timeout: timeout, file: file, line: line)
    }

    /// Waits for disappearance rather than reading a snapshot: `!exists` straight after an action
    /// passes for the wrong reason and starts failing once the app gets marginally faster.
    @discardableResult
    func assertDoesNotExist(
        timeout: TimeInterval = BrewUITestTimeout.disappearance,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected \(id.rawValue) to disappear within \(timeout)s",
            file: file,
            line: line,
        )
        return self
    }
}

/// Named so a call site says why a wait is longer than the rest, and so CI can be widened in one place.
enum BrewUITestTimeout {
    /// Rendering off already-loaded state.
    static let `default`: TimeInterval = 10
    static let disappearance: TimeInterval = 10
    /// Launch plus the first inventory fetch through the fake `brew`.
    static let launch: TimeInterval = 60
    /// A mutating run: spawn, stream, exit, then the repository's forced reconcile.
    static let command: TimeInterval = 30
}
