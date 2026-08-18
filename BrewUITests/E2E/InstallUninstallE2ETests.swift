//
//  InstallUninstallE2ETests.swift
//  BrewUITests
//

import XCTest

/// The two mutating canaries. They prove the whole chain the deterministic suite can only simulate:
/// a real catalogue decode, a real subprocess under the user's login shell, a real bottle poured from
/// ghcr.io, real output streamed into the console, and the real `brew info` refresh that follows.
///
/// Each test establishes its own precondition through ``Brew`` and tears it down again, so they are
/// order-independent and leave no residue. `hello` is owned by this suite — see `E2E/README.md`.
final class InstallUninstallE2ETests: BrewE2ETestCase {
    /// GNU Hello: no dependencies, a bottle that pours in seconds, and nothing on a developer machine
    /// legitimately depends on it being present or absent.
    private let canary = "hello"

    override func setUpWithError() throws {
        try super.setUpWithError()
        Brew.forceUninstall(canary)
    }

    /// Runs after ``BrewUITestCase/tearDown()`` has terminated the app, so the cleanup never contends
    /// with a still-running app for Homebrew's lock. Unconditional: a failed test is the case most
    /// likely to have left the canary installed.
    override func tearDown() {
        super.tearDown()
        Brew.forceUninstall(canary)
    }

    /// Discover → search → install. The assertions are structural: that a row for the canary exists,
    /// that output streamed, that the run ended in success, and that the package transitioned into
    /// Installed. No version, count or path is asserted, so a formula bump cannot turn this red.
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
            // The canary's name appearing in the body is proof real lines reached the UI through the
            // pipe/pty drain, rather than arriving as one blob at exit.
            .assertOutputContains(canary, timeout: BrewE2ETimeout.install)
            .assertSucceeded(timeout: BrewE2ETimeout.install)

        installed.sidebar
            .goToInstalled()
            // A real machine's inventory is long and the list virtualizes, so filter to the canary
            // rather than hoping its row happens to be rendered.
            .search(for: canary)
            .assertHasPackage(canary, timeout: BrewE2ETimeout.command)
    }

    /// The reverse transition, arranged outside the app so the test is independent of the one above.
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
