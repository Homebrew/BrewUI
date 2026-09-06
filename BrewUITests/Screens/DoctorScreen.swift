//
//  DoctorScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The Doctor tab, where a non-zero exit means warnings were found rather than that the run failed.
@MainActor
struct DoctorScreen: Screen {
    let app: XCUIApplication

    var root: BrewUIElement {
        BrewUIElement(app, .doctorScreen)
    }

    /// Command timeout: the report exists only once `brew doctor` has run.
    @discardableResult
    func assertShowsIssue(
        containing substring: String,
        timeout: TimeInterval = BrewUITestTimeout.command,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        // macOS exposes this `Text` through the accessibility *value*, not the *label*.
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

    /// `DoctorReport.placeholder` is not healthy, so this text exists only once `brew doctor` has run.
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
