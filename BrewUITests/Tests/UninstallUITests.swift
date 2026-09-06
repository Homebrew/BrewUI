//
//  UninstallUITests.swift
//  BrewUITests
//

import XCTest

/// The row goes because `brew uninstall` exits 0, the centre publishes running→idle and the repository
/// refetches — not because the test asked for it.
final class UninstallUITests: BrewUITestCase {
    @MainActor
    func testUninstallRemovesPackage() {
        launch(.installedBasic)
            .assertHasPackage("wget")
            .openDetail(for: "wget")
            .uninstall()
            .assertDoesNotHavePackage("wget", timeout: BrewUITestTimeout.command)
    }

    @MainActor
    func testUninstallLeavesOtherPackagesInPlace() {
        launch(.installedBasic)
            .openDetail(for: "wget")
            .uninstall()
            .assertDoesNotHavePackage("wget", timeout: BrewUITestTimeout.command)
            .assertHasPackage("iterm2")
            .assertHasPackage("ripgrep")
    }
}
