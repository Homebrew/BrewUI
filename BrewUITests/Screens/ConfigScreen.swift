//
//  ConfigScreen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The Configuration tab: parsed `brew config` output, or the brew-not-found empty state.
@MainActor
struct ConfigScreen: Screen {
    let app: XCUIApplication

    var root: BrewUIElement {
        BrewUIElement(app, .configScreen)
    }

    /// Matched on rendered text because the cards are data-driven, with no per-row identity to address.
    /// Command timeout, not render timeout: the cards exist only once `brew config` has been parsed.
    @discardableResult
    func assertShowsEntry(
        _ key: String,
        timeout: TimeInterval = BrewUITestTimeout.command,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        let text = root.element.staticTexts[key]
        guard text.waitForExistence(timeout: timeout) else {
            XCTFail(
                """
                Expected Configuration to show a “\(key)” entry within \(timeout)s.
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
    func assertShowsBrewNotFound(
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        BrewUIElement(app, .brewNotFoundState).waitToExist(timeout: timeout, file: file, line: line)
        return self
    }
}
