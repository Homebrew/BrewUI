//
//  SecurityUITests.swift
//  BrewUITests
//

import XCTest

/// The Security tab, where a non-zero `brew vulns` exit means "found advisories" rather than "failed".
final class SecurityUITests: BrewUITestCase {
    @MainActor
    func testListsAdvisoriesFromANonZeroExit() {
        let installed = launch(.securityHasAdvisories)

        installed.sidebar
            .goToSecurity()
            .assertListsPackage("openjpeg")
            .assertShowsAdvisory("OSV-2025-219")
    }

    @MainActor
    func testShowsCleanStateWhenNothingIsOpen() {
        let installed = launch(.empty)

        installed.sidebar
            .goToSecurity()
            .assertIsClean()
    }
}
