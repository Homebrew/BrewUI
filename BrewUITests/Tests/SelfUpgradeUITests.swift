//
//  SelfUpgradeUITests.swift
//  BrewUITests
//

import AppKit
import BrewAccessibilityID
import XCTest

/// The self-upgrade handshake end to end, with nothing simulated: the app really terminates, the real
/// helper runs `brew upgrade --cask homebrew-app` against the fake `brew`, and brings back a new process.
@MainActor
final class SelfUpgradeUITests: BrewUITestCase {
    func testBannerOffersAnUpgradeWhenTheAppsOwnCaskIsOutdated() {
        launch(.selfUpgradeAvailable)
            .sidebar
            .goToUpgrades()
            .assertShowsSelfUpgradeBanner()
    }

    func testBannerAlsoAppearsAboveTheInstalledList() {
        launch(.selfUpgradeAvailable)
            .assertShowsSelfUpgradeBanner()
    }

    func testBannerAlsoAppearsOnDiscover() {
        launch(.selfUpgradeAvailable)
            .sidebar
            .goToDiscover()
            .assertShowsSelfUpgradeBanner()
    }

    /// The banner owns the app's own cask; the list would offer an in-process upgrade of it.
    func testTheAppsOwnCaskIsNotAnOrdinaryRow() {
        let installed = launch(.selfUpgradeAvailable)
            .assertShowsSelfUpgradeBanner()
            .assertHasPackage("ripgrep")
            .assertDoesNotHavePackage("homebrew-app")

        installed.sidebar
            .goToUpgrades()
            .assertHasPackage("ripgrep")
            .assertDoesNotHavePackage("homebrew-app")
    }

    /// Dismissal is the app's, not the list's, so it has to hold as the tabs change.
    func testLaterDismissesTheBannerEverywhere() {
        let installed = launch(.selfUpgradeAvailable)
            .assertShowsSelfUpgradeBanner()
            .deferSelfUpgrade()
            .assertHidesSelfUpgradeBanner()

        installed.sidebar
            .goToUpgrades()
            .assertHidesSelfUpgradeBanner()
            .assertHasPackage("ripgrep")
    }

    /// The whole handshake in one pass, ending with the relaunched app reporting the outcome once.
    func testUpgradingQuitsRelaunchesAndAcknowledgesOnTheNextLaunch() throws {
        let relaunched = try upgradeAndWaitForRelaunch(.selfUpgradeRunsBrew)
        defer { relaunched.terminate() }

        XCTAssertTrue(
            relaunched.staticTexts[Self.successAlertTitle].waitForExistence(timeout: BrewUITestTimeout.launch),
            "The relaunched app did not report the upgrade",
        )

        BrewUIButton(relaunched, .selfUpgradeOutcomeAcknowledgeButton).tap()

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

    /// Saying nothing would leave the user believing they had upgraded.
    func testAnUpgradeThatExitsNonZeroIsReportedOnTheNextLaunch() throws {
        let relaunched = try upgradeAndWaitForRelaunch(.selfUpgradeBrewFails)
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
        installed.assertShowsSelfUpgradeBanner()

        let originalProcessIdentifier = try XCTUnwrap(
            Self.runningAppUnderTest()?.processIdentifier,
            "Could not identify the app process before starting the upgrade",
        )

        installed.startSelfUpgrade()

        XCTAssertTrue(
            app.wait(for: .notRunning, timeout: BrewUITestTimeout.command),
            "The app did not quit — the handoff never reached the helper",
        )

        return try Self.waitForRelaunch(replacing: originalProcessIdentifier)
    }

    // MARK: Relaunch

    private static let appBundleIdentifier = "sh.brew.app"

    /// `/DerivedData/` narrows this to the build under test; a real install shares the identifier.
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
        The upgrade helper did not relaunch the app within \(timeout)s. Check `HomebrewUpgradeHelper` is present \
        in Contents/Helpers and that this build is signed — LaunchServices refuses to open an unsigned bundle, \
        which surfaces here as a relaunch that never arrives.
        """
    }
}
