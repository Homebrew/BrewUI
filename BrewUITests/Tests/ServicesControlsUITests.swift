//
//  ServicesControlsUITests.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// Runtime controls against fake brew, including the refreshed inventory and shared console.
final class ServicesControlsUITests: BrewUITestCase {
    @MainActor
    func testStartingAServiceDoesNotRegisterItAtLogin() {
        let services = launch(.servicesControls).sidebar.goToServices().select("postgresql@17")
        services.assertRuntimeCommandContains("brew services run postgresql@17")
        services.performRuntimeAction()

        services.console.assertOutputContains("Successfully ran").assertSucceeded()
        services.assertRuntimeActionTitle("Stop")
        services.detailValue(.pid).assertContains("43212")
        services.detailValue(.startsAtLogin).assertContains("No")
    }

    @MainActor
    func testStoppingAServicePreservesItsLoginRegistration() {
        let services = launch(.servicesControls).sidebar.goToServices().select("redis")
        services.assertRuntimeCommandContains("brew services stop --keep redis")
        services.performRuntimeAction()

        services.console.assertOutputContains("Successfully stopped").assertSucceeded()
        services.assertRuntimeActionTitle("Start")
        services.detailValue(.pid).assertContains("—")
        services.detailValue(.startsAtLogin).assertContains("Yes")
    }

    @MainActor
    func testRestartingAServicePreservesItsLoginRegistration() {
        let services = launch(.servicesControls).sidebar.goToServices().select("redis")
        services.assertRestartCommandContains("brew services restart redis")
        services.restart()

        services.console.assertOutputContains("Successfully started").assertSucceeded()
        services.detailValue(.pid).assertContains("43211")
        services.detailValue(.startsAtLogin).assertContains("Yes")
    }

    @MainActor
    func testFailedStartReportsTheErrorAndKeepsTheServiceStopped() {
        let services = launch(.servicesControlFailure).sidebar.goToServices().select("postgresql@17")
        services.performRuntimeAction()

        services.console.assertOutputContains("permission denied").assertFailed(exitCode: 1)
        services.actionError.assertContains("permission denied")
        services.refreshButton.tap()
        services.assertRuntimeActionTitle("Start")
        services.detailValue(.pid).assertContains("—")
        services.detailValue(.startsAtLogin).assertContains("No")
    }

    @MainActor
    func testRootAndOtherUserServicesStayReadOnly() {
        let services = launch(.servicesControls).sidebar.goToServices()
        for name in ["mysql", "nginx"] {
            services.select(name).assertActionsUnavailable()
        }
    }
}
