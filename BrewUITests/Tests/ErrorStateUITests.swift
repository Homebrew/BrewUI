//
//  ErrorStateUITests.swift
//  BrewUITests
//

import XCTest

/// The failure paths, and the reason this suite mocks process boundaries rather than repositories:
/// every error here is real app code reacting to real bad input, not a stubbed error value.
final class ErrorStateUITests: BrewUITestCase {
    @MainActor
    func testCatalogueServerErrorShowsDiscoverError() {
        let installed = launch(.catalogueServerError)

        installed.sidebar
            .goToDiscover()
            .assertShowsErrorState()
    }

    @MainActor
    func testCatalogueServerErrorShowsSearchError() {
        let installed = launch(.catalogueServerError)

        installed.sidebar
            .goToDiscover()
            .search(for: "ripgrep")
            .assertShowsErrorState()
    }

    /// Exits 0 with a non-JSON body, so the failure comes from the decode step.
    @MainActor
    func testMalformedInstalledJSONShowsInstalledError() {
        let app = launchUnverified(.malformedInstalledInfo)

        InstalledScreen(app: app)
            .waitUntilLoaded(timeout: BrewUITestTimeout.launch)
            .assertShowsErrorState()
    }

    /// Configuration has a dedicated empty state for this, distinct from a generic load failure.
    @MainActor
    func testBrewNotFoundShowsTheLocatorEmptyState() {
        let app = launchUnverified(.brewNotFound)

        InstalledScreen(app: app)
            .waitUntilLoaded(timeout: BrewUITestTimeout.launch)
            .sidebar
            .goToConfiguration()
            .assertShowsBrewNotFound()
    }

    /// "Nothing installed" and "couldn't ask" must not look the same.
    @MainActor
    func testBrewNotFoundShowsInstalledError() {
        let app = launchUnverified(.brewNotFound)

        InstalledScreen(app: app)
            .waitUntilLoaded(timeout: BrewUITestTimeout.launch)
            .assertShowsErrorState()
    }

    /// Without this, every assertion above could be passing for the wrong reason.
    @MainActor
    func testHealthyScenarioShowsNoErrorState() {
        launch(.installedBasic)
            .assertShowsNoErrorState()
    }
}
