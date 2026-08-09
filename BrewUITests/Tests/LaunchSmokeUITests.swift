//
//  LaunchSmokeUITests.swift
//  BrewUITests
//

import XCTest

/// Harness smoke test: a `-uiTesting` launch reaches the stubbed wiring and `AXID` resolves against
/// the running app. When it fails alongside half the suite, read it first — everything assumes it.
final class LaunchSmokeUITests: BrewUITestCase {
    @MainActor
    func testLaunchesIntoTheStubbedComposition() {
        launch(.empty)
            .sidebar
            .waitUntilLoaded(timeout: BrewUITestTimeout.launch)
    }

    /// An empty inventory, not a failure that happens to render no rows.
    @MainActor
    func testEmptyScenarioShowsAnEmptyInventoryNotAFailure() {
        launch(.empty)
            .assertShowsNoErrorState()
            .assertRowCount(0)
    }
}
