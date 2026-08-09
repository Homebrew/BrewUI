//
//  DoctorUITests.swift
//  BrewUITests
//

import XCTest

/// The Doctor tab, where a non-zero exit means "found warnings" rather than "the command failed".
final class DoctorUITests: BrewUITestCase {
    @MainActor
    func testReportsWarningsFromANonZeroExit() {
        let installed = launch(.doctorHasIssues)

        installed.sidebar
            .goToDoctor()
            .assertShowsIssue(containing: "deprecated or disabled")
    }

    @MainActor
    func testShowsHealthyStateWhenDoctorFindsNothing() {
        let installed = launch(.empty)

        installed.sidebar
            .goToDoctor()
            .assertIsHealthy()
    }
}
