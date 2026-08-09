//
//  DoctorScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The Doctor tab. `brew doctor` exits non-zero when it finds warnings and the repository treats that
/// as data, so a scenario with issues is still a successful run.
@MainActor
struct DoctorScreen: Screen {
    let app: XCUIApplication

    var root: BrewUIElement {
        BrewUIElement(app, .doctorScreen)
    }

    /// Command timeout for the same reason as ``assertIsHealthy(timeout:file:line:)``: the report only
    /// exists once `brew doctor` has run.
    @discardableResult
    func assertShowsIssue(
        containing substring: String,
        timeout: TimeInterval = BrewUITestTimeout.command,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        // See `ConsoleScreen.assertOutputContains`: this text renders through a `Text` whose content
        // macOS exposes via the accessibility *value*, not the *label*.
        let predicate = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", substring, substring)
        let match = root.element.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(
            match.waitForExistence(timeout: timeout),
            "Expected Doctor to report an issue containing “\(substring)” within \(timeout)s",
            file: file,
            line: line,
        )
        return self
    }

    /// Command timeout, not render timeout: `DoctorReport.placeholder` is not healthy, so this text
    /// does not exist until the `brew doctor` subprocess finishes.
    @discardableResult
    func assertIsHealthy(
        timeout: TimeInterval = BrewUITestTimeout.command,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        let healthy = root.element.staticTexts["Your system is ready to brew"]
        guard healthy.waitForExistence(timeout: timeout) else {
            XCTFail(
                """
                Expected Doctor to show the healthy state within \(timeout)s.
                \(BrewUITestDiagnostics.report(for: app))
                """,
                file: file,
                line: line,
            )
            return self
        }
        return self
    }
}
