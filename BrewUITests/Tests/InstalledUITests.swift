//
//  InstalledUITests.swift
//  BrewUITests
//

import XCTest

/// The Installed tab end to end: the fake writes `--json=v2` to a real pipe, the real service drains
/// it, the real repository decodes it, and these rows are what SwiftUI made of the result.
final class InstalledUITests: BrewUITestCase {
    @MainActor
    func testRendersFormulaeAndCasksTogether() {
        launch(.installedBasic)
            .assertHasPackage("wget")
            .assertHasPackage("ripgrep")
            .assertHasPackage("iterm2")
            .assertHasPackage("rectangle")
    }

    @MainActor
    func testSearchFiltersTheList() {
        launch(.installedBasic)
            .search(for: "wget")
            .assertHasPackage("wget")
            .assertDoesNotHavePackage("iterm2")
    }

    @MainActor
    func testClearingSearchRestoresTheList() {
        launch(.installedBasic)
            .search(for: "wget")
            .assertDoesNotHavePackage("iterm2")
            .clearSearch()
            .assertHasPackage("iterm2")
    }

    @MainActor
    func testOutdatedPackageAppearsUnderUpgrades() {
        let installed = launch(.installedBasic)

        installed.sidebar
            .goToUpgrades()
            .assertHasPackage("ripgrep")
            .assertDoesNotHavePackage("wget")
    }

    /// Real inventories overrun a pipe buffer. The runner drains concurrently with the process;
    /// reading after `waitUntilExit` would deadlock on exactly this input.
    @MainActor
    func testRendersAnInventoryLargerThanOnePipeBuffer() {
        launch(.installedLarge)
            .assertHasPackage("bulk-formula-000")
    }
}
