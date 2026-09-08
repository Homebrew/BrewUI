//
//  SelfUpdateUITests.swift
//  BrewUITests
//

import AppKit
import BrewAccessibilityID
import XCTest

/// The self-update handshake end to end: the app really terminates, the real helper waits for it, really runs
/// `brew upgrade --cask homebrew-app` against the fake `brew`, and the app it brings back is a new process.
@MainActor
final class SelfUpdateUITests: BrewUITestCase {
    func testBannerOffersAnUpgradeWhenTheAppsOwnCaskIsOutdated() {
        launch(.selfUpdateAvailable)
            .sidebar
            .goToUpgrades()
            .assertShowsSelfUpdateBanner()
    }

    func testBannerAlsoAppearsAboveTheInstalledList() {
        launch(.selfUpdateAvailable)
            .assertShowsSelfUpdateBanner()
    }

    func testBannerAlsoAppearsOnDiscover() {
        launch(.selfUpdateAvailable)
            .sidebar
            .goToDiscover()
            .assertShowsSelfUpdateBanner()
    }

    /// The banner owns the app's own cask. Left in the list it would offer an in-process
    /// `brew upgrade --cask homebrew-app`, which is the one thing the handoff exists to avoid.
    func testTheAppsOwnCaskIsNotAnOrdinaryRow() {
        let installed = launch(.selfUpdateAvailable)
            .assertShowsSelfUpdateBanner()
            .assertHasPackage("ripgrep")
            .assertDoesNotHavePackage("homebrew-app")

        installed.sidebar
            .goToUpgrades()
            .assertHasPackage("ripgrep")
            .assertDoesNotHavePackage("homebrew-app")
    }

    /// Dismissal is the app's, not the list's, so it has to hold as the tabs change.
    func testLaterDismissesTheBannerEverywhere() {
        let installed = launch(.selfUpdateAvailable)
            .assertShowsSelfUpdateBanner()
            .deferSelfUpdate()
            .assertHidesSelfUpdateBanner()

        installed.sidebar
            .goToUpgrades()
            .assertHidesSelfUpdateBanner()
            .assertHasPackage("ripgrep")
    }

    func testUpgradingQuitsRelaunchesAndAcknowledgesOnTheNextLaunch() throws {
        let relaunched = try upgradeAndWaitForRelaunch(.selfUpdateAvailable)
        defer { relaunched.terminate() }

        XCTAssertTrue(
            relaunched.staticTexts[Self.successAlertTitle].waitForExistence(timeout: BrewUITestTimeout.launch),
            "The relaunched app did not report the upgrade",
        )

        BrewUIButton(relaunched, .selfUpdateOutcomeAcknowledgeButton).tap()

        let dismissed = NSPredicate(format: "exists == false")
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(
                    predicate: dismissed,
                    object: relaunched.staticTexts[Self.successAlertTitle],
                )],
                timeout: BrewUITestTimeout.disappearance,
            ),
            .completed,
            "Acknowledging the outcome did not dismiss the alert",
        )
    }

    /// The simulated path steps over the subprocess entirely, so this is the only test that proves the
    /// helper runs `brew upgrade --cask homebrew-app` at all.
    func testTheHelperReallyRunsBrewAndTheAppComesBackReportingSuccess() throws {
        let relaunched = try upgradeAndWaitForRelaunch(.selfUpdateRunsBrew)
        defer { relaunched.terminate() }

        XCTAssertTrue(
            relaunched.staticTexts[Self.successAlertTitle].waitForExistence(timeout: BrewUITestTimeout.launch),
            "The relaunched app did not report the upgrade as successful",
        )
    }

    /// A failed upgrade relaunches an app that looks exactly like an ordinary start, so saying nothing
    /// would leave the user believing they had upgraded.
    func testAnUpgradeThatExitsNonZeroIsReportedOnTheNextLaunch() throws {
        let relaunched = try upgradeAndWaitForRelaunch(.selfUpdateBrewFails)
        defer { relaunched.terminate() }

        XCTAssertTrue(
            relaunched.staticTexts[Self.failureAlertTitle].waitForExistence(timeout: BrewUITestTimeout.launch),
            "The relaunched app did not report the failed upgrade",
        )
        XCTAssertFalse(
            relaunched.staticTexts[Self.successAlertTitle].exists,
            "A failed upgrade was reported as a success",
        )
    }

    // MARK: Handoff

    private static let successAlertTitle = "The Homebrew app is up to date"
    private static let failureAlertTitle = "The Homebrew app wasn’t upgraded"

    private func upgradeAndWaitForRelaunch(_ scenario: BrewUITestScenario) throws -> XCUIApplication {
        let app = launchUnverified(scenario)
        // Waited for explicitly because this test needs the `XCUIApplication` itself, to watch it terminate.
        let installed = InstalledScreen(app: app).waitUntilLoaded(timeout: BrewUITestTimeout.launch)
        installed.assertShowsSelfUpdateBanner()

        let originalProcessIdentifier = try XCTUnwrap(
            Self.runningAppUnderTest()?.processIdentifier,
            "Could not identify the app process before starting the upgrade",
        )

        installed.startSelfUpdate()

        XCTAssertTrue(
            app.wait(for: .notRunning, timeout: BrewUITestTimeout.command),
            "The app did not quit — the handoff never reached the helper",
        )

        return try Self.waitForRelaunch(replacing: originalProcessIdentifier)
    }

    // MARK: Relaunch

    private static let appBundleIdentifier = "sh.brew.app"

    /// `/DerivedData/` narrows this to the build under test: a developer machine can have a real install
    /// carrying the same identifier.
    private static func runningAppUnderTest() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier == appBundleIdentifier }
            .filter { $0.executableURL?.path.contains("/DerivedData/") == true }
            .max(by: { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) })
    }

    /// A *different* pid, so a slow quit isn't mistaken for a completed relaunch.
    private static func waitForRelaunch(
        replacing originalProcessIdentifier: pid_t,
        timeout: TimeInterval = BrewUITestTimeout.launch,
    ) throws -> XCUIApplication {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let running = runningAppUnderTest(), running.processIdentifier != originalProcessIdentifier {
                let relaunched = XCUIApplication(bundleIdentifier: appBundleIdentifier)
                _ = relaunched.wait(for: .runningForeground, timeout: BrewUITestTimeout.launch)
                return relaunched
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        throw RelaunchFailure(timeout: timeout)
    }
}

private struct RelaunchFailure: LocalizedError {
    let timeout: TimeInterval

    var errorDescription: String? {
        """
        The update helper did not relaunch the app within \(timeout)s. Check `HomebrewUpdateHelper` is present \
        in Contents/Helpers and that this build is signed — LaunchServices refuses to open an unsigned bundle, \
        which surfaces here as a relaunch that never arrives.
        """
    }
}
