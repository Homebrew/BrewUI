//
//  CleanupUITests.swift
//  BrewUITests
//

import XCTest

/// Tools › Clean Up… lists what `brew cleanup --dry-run` reports, before anything is removed.
final class CleanupUITests: BrewUITestCase {
    @MainActor
    func testListsWhatADryRunWouldRemoveAndCancels() {
        let installed = launch(.cleanupHasItems)

        installed
            .openCleanup()
            .assertListsItem("libyaml")
            .assertListsItem("/fixtures/Caches/Homebrew/wget--1.24.5.arm64_sequoia.bottle.tar.gz")
            .cancel()
            .assertIsClosed()
    }

    @MainActor
    func testShowsCleanStateWhenThereIsNothingToRemove() {
        let installed = launch(.empty)

        installed
            .openCleanup()
            .assertIsClean()
            .done()
            .assertIsClosed()
    }
}
