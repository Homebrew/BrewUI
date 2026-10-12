//
//  ServicesUITests.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// The read-only Services tab against a fixture inventory: redis running, postgresql@17 never
/// started and unbound failed with exit code 78.
final class ServicesUITests: BrewUITestCase {
    @MainActor
    func testEmptyInventoryShowsTheEmptyState() {
        launch(.empty).sidebar.goToServices()
            .assertShowsInventory()
            .assertShowsNoErrorState()
    }

    @MainActor
    func testRunningFilterHidesStoppedServices() {
        let services = launch(.servicesBasic).sidebar.goToServices()
        services.row("unbound").waitToExist()
        services.show(.running)
        services.row("unbound").assertDoesNotExist()
    }

    @MainActor
    func testStoppedFilterHidesRunningServices() {
        let services = launch(.servicesBasic).sidebar.goToServices()
        services.row("redis").waitToExist()
        services.show(.stopped)
        services.row("redis").assertDoesNotExist()
    }

    @MainActor
    func testRefreshKeepsTheInventory() {
        let services = launch(.servicesBasic).sidebar.goToServices()
        services.row("redis").waitToExist()
        services.refreshButton.tap()
        services.row("redis").assertExists()
    }

    /// Regression: only the text in a row used to take the click.
    @MainActor
    func testClickingTrailingRowSpaceSelectsTheService() {
        let services = launch(.servicesBasic).sidebar.goToServices()
        services.select("unbound")
        services.row("redis").element.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).click()
        services.detailValue(.pid).assertContains("43210")
    }

    @MainActor
    func testFilteringPreservesTheDetailPaneWidth() throws {
        let services = launch(.servicesBasic).sidebar.goToServices().select("redis")
        let detail = BrewUIElement(services.app, .serviceDetail).waitToExist().element
        let divider = try XCTUnwrap(services.app.splitters.allElementsBoundByIndex.min {
            abs($0.frame.midX - detail.frame.minX) < abs($1.frame.midX - detail.frame.minX)
        })
        let dividerX = divider.frame.midX
        for scope in [ServicesScreen.Scope.stopped, .running, .all] {
            services.show(scope)
            XCTAssertEqual(divider.frame.midX, dividerX, accuracy: 2, "Divider moved for \(scope)")
        }
    }

    @MainActor
    func testRunningServiceShowsItsProcessAndPaths() {
        let services = launch(.servicesBasic).sidebar.goToServices().select("redis")
        services.detailValue(.pid).assertContains("43210")
        services.detailValue(.file).assertContains("/fixtures/redis.plist")
        services.detailValue(.errorLogPath).assertContains("/fixtures/redis-error.log")
    }

    @MainActor
    func testUnreportedLoginRegistrationReadsAsUnknown() {
        launch(.servicesBasic).sidebar.goToServices().select("unbound")
            .detailValue(.startsAtLogin).assertContains("Unknown")
    }

    @MainActor
    func testFailedServiceShowsItsExitCode() {
        launch(.servicesBasic).sidebar.goToServices().select("unbound")
            .detailValue(.exitCode).assertContains("78")
    }

    @MainActor
    func testFailedServiceWithoutAnErrorLogSaysSo() {
        launch(.servicesBasic).sidebar.goToServices().select("unbound")
            .detailValue(.errorGuidance).assertContains("No error log path reported.")
    }

    @MainActor
    func testArrowKeysMoveTheSelection() {
        // Sorted by name, so unbound follows redis.
        let services = launch(.servicesBasic).sidebar.goToServices().select("redis")
        services.app.typeKey(.downArrow, modifierFlags: [])
        services.detailValue(.exitCode).assertContains("78")
    }
}
