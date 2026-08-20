//
//  InstallUninstallE2ETests.swift
//  BrewUITests
//

import XCTest

/// The mutating canaries: a real catalogue decode, a real subprocess under the user's login shell, a
/// real bottle poured from ghcr.io, and the real `brew info` refresh that follows.
///
/// `hello` is owned by this suite and nothing may depend on it — see `E2E/README.md`.
final class InstallUninstallE2ETests: BrewE2ETestCase {
    private let canary = "hello"

    override func setUpWithError() throws {
        try super.setUpWithError()
        Brew.forceUninstall(canary)
    }

    /// Cleans up after ``BrewUITestCase/tearDown()`` has terminated the app, so it never contends with
    /// a running app for Homebrew's lock.
    override func tearDown() {
        super.tearDown()
        Brew.forceUninstall(canary)
    }

    @MainActor
    func testInstallingFromDiscoverAddsThePackageToInstalled() {
        let installed = launchLive()

        installed.sidebar
            .goToDiscover()
            .search(for: canary)
            .assertHasPackage(canary, timeout: BrewE2ETimeout.catalogue)
            .openDetail(for: canary)
            .install()
            .console
            .assertOutputContains(canary, timeout: BrewE2ETimeout.install)
            .assertSucceeded(timeout: BrewE2ETimeout.install)

        installed.sidebar
            .goToInstalled()
            // A real machine's inventory is long and the list virtualizes, so an installed row may
            // never render unfiltered.
            .search(for: canary)
            .assertHasPackage(canary, timeout: BrewE2ETimeout.command)
    }

    @MainActor
    func testUninstallingFromInstalledRemovesThePackage() throws {
        try Brew.run("install", "--formula", canary)

        launchLive()
            .search(for: canary)
            .assertHasPackage(canary, timeout: BrewE2ETimeout.command)
            .openDetail(for: canary)
            .uninstall()
            .assertDoesNotHavePackage(canary, timeout: BrewE2ETimeout.uninstall)
    }
}
