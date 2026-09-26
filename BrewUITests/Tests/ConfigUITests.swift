//
//  ConfigUITests.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The Configuration tab renders what `BrewConfigParser` made of the fake's `brew config` output.
final class ConfigUITests: BrewUITestCase {
    @MainActor
    func testRendersParsedConfigEntries() {
        let installed = launch(.installedBasic)

        installed.sidebar
            .goToConfiguration()
            .assertShowsEntry("HOMEBREW_VERSION")
            .assertShowsEntry("HOMEBREW_PREFIX")
    }

    @MainActor
    func testFormulaBottleSettingCanBeChangedAndRestored() throws {
        let installed = launch(.installedBasic)
        let config = installed.sidebar.goToConfiguration()
        let toggle = config.app.switches[AXID.forceBottleFormulaeSwitch.rawValue]
        XCTAssertTrue(toggle.waitForExistence(timeout: BrewUITestTimeout.command))
        let originalValue = try XCTUnwrap(toggle.value as? String)

        toggle.tap()
        XCTAssertNotEqual(toggle.value as? String, originalValue)
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, originalValue)
    }
}
