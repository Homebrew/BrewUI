//
//  SecurityScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The Security tab, where a non-zero `brew vulns` exit means advisories were found rather than that
/// the scan failed.
@MainActor
struct SecurityScreen: Screen {
    let app: XCUIApplication

    var root: BrewUIElement {
        BrewUIElement(app, .securityScreen)
    }

    /// Command timeout: rows exist only once `brew vulns` has run.
    @discardableResult
    func assertListsPackage(
        _ token: String,
        timeout: TimeInterval = BrewUITestTimeout.command,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        BrewUIElement(app, .securityRow(token: token)).assertExists(timeout: timeout, file: file, line: line)
        return self
    }

    @discardableResult
    func assertShowsAdvisory(
        _ id: String,
        timeout: TimeInterval = BrewUITestTimeout.command,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        BrewUIElement(app, .securityAdvisory(id: id)).assertExists(timeout: timeout, file: file, line: line)
        return self
    }

    /// The placeholder report has findings, so the clean state exists only once `brew vulns` has run.
    @discardableResult
    func assertIsClean(
        timeout: TimeInterval = BrewUITestTimeout.command,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        BrewUIElement(app, .securityCleanState).assertExists(timeout: timeout, file: file, line: line)
        return self
    }
}
