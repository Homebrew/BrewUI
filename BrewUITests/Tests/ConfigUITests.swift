//
//  ConfigUITests.swift
//  BrewUITests
//

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
}
