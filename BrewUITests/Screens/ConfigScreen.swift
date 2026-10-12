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

    /// Matched on rendered text — the cards carry no per-row identity — and only exist once parsed.
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

    @discardableResult
    func assertProxyAuthenticationUsesSecureField(
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        let picker = BrewUIElement(app, .proxySettingsModePicker).waitToExist(file: file, line: line)
        let manual = picker.element.radioButtons["Manual proxy configuration"]
        for _ in 0 ..< 5 where !manual.isHittable {
            root.element.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -300)
        }
        XCTAssertTrue(manual.isHittable, file: file, line: line)
        manual.click()

        let authentication = BrewUIButton(app, .proxySettingsAuthenticationToggle)
        for _ in 0 ..< 5 where !authentication.element.isHittable {
            root.element.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -300)
        }
        authentication.tap(file: file, line: line)
        BrewUIElement(app, .proxySettingsField(.password), type: .secureTextField)
            .assertExists(file: file, line: line)
        let fields: [(AXID.BrewProxySettingsField, String)] = [
            (.host, "Host name"), (.port, "Port number"), (.noProxy, "No proxy for"),
            (.username, "Login"), (.password, "Password"),
        ]
        for (field, label) in fields {
            let control = field == .password
                ? app.secureTextFields[AXID.proxySettingsField(field).rawValue]
                : app.textFields[AXID.proxySettingsField(field).rawValue]
            XCTAssertEqual(control.label, label, file: file, line: line)
        }
        XCTAssertFalse(
            app.textFields[AXID.proxySettingsField(.password).rawValue].exists,
            "Proxy passwords must not be exposed in a plain text field",
            file: file,
            line: line,
        )
        return self
    }
}
