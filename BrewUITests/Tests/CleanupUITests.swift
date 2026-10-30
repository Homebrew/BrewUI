//
//  CleanupUITests.swift
//  BrewUITests
//

import XCTest

/// The Cleanup tab lists what `brew cleanup --dry-run` reports, before anything is removed.
final class CleanupUITests: BrewUITestCase {
    @MainActor
    func testListsWhatADryRunWouldRemove() {
        let installed = launch(.cleanupHasItems)

        installed.sidebar
            .goToCleanup()
            .assertListsItem("libyaml")
            .assertListsItem("/fixtures/Caches/Homebrew/wget--1.24.5.arm64_sequoia.bottle.tar.gz")
    }

    @MainActor
    func testShowsCleanStateWhenThereIsNothingToRemove() {
        let installed = launch(.empty)

        installed.sidebar
            .goToCleanup()
            .assertIsClean()
    }
}
