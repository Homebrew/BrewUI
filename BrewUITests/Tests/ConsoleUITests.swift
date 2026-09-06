//
//  ConsoleUITests.swift
//  BrewUITests
//

import XCTest

/// Asserting on individual lines is what proves the output streamed rather than arriving at exit.
final class ConsoleUITests: BrewUITestCase {
    @MainActor
    func testStreamsOutputAndReportsSuccess() {
        let installed = launch(.discoverSearch)

        installed.sidebar
            .goToDiscover()
            .search(for: "ripgrep")
            .openDetail(for: "ripgrep")
            .install()
            .console
            .assertOutputContains("Fetching ripgrep")
            .assertOutputContains("Pouring ripgrep")
            .assertSucceeded()
    }

    @MainActor
    func testSurfacesStderrAndTheExitCodeWhenACommandFails() {
        let installed = launch(.installFailure)

        installed.sidebar
            .goToDiscover()
            .search(for: "ripgrep")
            .openDetail(for: "ripgrep")
            .install()
            .console
            .assertOutputContains("git clone` exited with 128")
            .assertFailed(exitCode: 1)
    }

    /// A failed install must not read as success anywhere.
    @MainActor
    func testFailedInstallDoesNotAddThePackage() {
        let installed = launch(.installFailure)

        installed.sidebar
            .goToDiscover()
            .search(for: "ripgrep")
            .openDetail(for: "ripgrep")
            .install()
            .console
            .assertFailed(exitCode: 1)

        installed.sidebar
            .goToInstalled()
            .assertDoesNotHavePackage("ripgrep")
    }
}
