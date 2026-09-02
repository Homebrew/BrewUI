//
//  ConsoleScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The console panel pinned to the bottom of every screen. Output lives in the expanded body and the
/// terminal success/failure sentence in the collapsed strip, so assertions say which side they need.
@MainActor
struct ConsoleScreen: Screen {
    let app: XCUIApplication

    var root: BrewUIElement {
        BrewUIElement(app, .console)
    }

    var output: BrewUIElement {
        BrewUIElement(app, .consoleOutput)
    }

    var status: BrewUIStaticText {
        BrewUIStaticText(app, .consoleStatus)
    }

    private var toggle: BrewUIButton {
        BrewUIButton(app, .consoleToggle)
    }

    @discardableResult
    func expand(file: StaticString = #filePath, line: UInt = #line) -> Self {
        setExpanded(true, file: file, line: line)
    }

    @discardableResult
    func collapse(file: StaticString = #filePath, line: UInt = #line) -> Self {
        setExpanded(false, file: file, line: line)
    }

    /// The toggle's label is the state read: exactly one of "Show console" / "Hide console" is mounted.
    ///
    /// Expansion is `@SceneStorage`-backed so it survives launches, and the app auto-expands on its own
    /// when a command starts. Read-decide-act would race that, so this waits for the state it wants
    /// first and only clicks if that settles the other way.
    @discardableResult
    private func setExpanded(
        _ expanded: Bool,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        let wanted = expanded ? "Hide console" : "Show console"
        if !waitForToggleLabel(wanted, timeout: 2) {
            toggle.tap(file: file, line: line)
            XCTAssertTrue(
                waitForToggleLabel(wanted, timeout: BrewUITestTimeout.default),
                "Console did not become \(expanded ? "expanded" : "collapsed")",
                file: file,
                line: line,
            )
        }
        return self
    }

    private func waitForToggleLabel(_ label: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: toggle.element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// A line reaching the body is proof the run streamed through the real pipe drain rather than
    /// arriving as one blob at exit.
    @discardableResult
    func assertOutputContains(
        _ substring: String,
        timeout: TimeInterval = BrewUITestTimeout.command,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        expand(file: file, line: line)
        // macOS exposes text through the accessibility *value*, with no label at all, so matching on
        // label alone silently never matches.
        let predicate = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", substring, substring)
        let match = output.element.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(
            match.waitForExistence(timeout: timeout),
            "Expected console output to contain “\(substring)” within \(timeout)s",
            file: file,
            line: line,
        )
        return self
    }

    /// The collapsed strip reads `<command> — done`, or `<command> — failed · exit N`.
    @discardableResult
    func assertSucceeded(
        timeout: TimeInterval = BrewUITestTimeout.command,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        collapse(file: file, line: line)
        status.assertContains("done", timeout: timeout, file: file, line: line)
        return self
    }

    @discardableResult
    func assertFailed(
        exitCode: Int32,
        timeout: TimeInterval = BrewUITestTimeout.command,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        collapse(file: file, line: line)
        status.assertContains("failed · exit \(exitCode)", timeout: timeout, file: file, line: line)
        return self
    }
}
