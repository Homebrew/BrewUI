//
//  BrewE2ETestCase.swift
//  BrewUITests
//

import XCTest

/// Base class for the live suite: the deterministic suite's process hygiene, with production wiring
/// against real brew and the real network (``BrewE2EApp``) in place of the stubbed launch.
///
/// Tests arrange and clean up by shelling out (``Brew``), and act through the shared page objects.
class BrewE2ETestCase: BrewUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try Brew.requireAvailable()
    }

    @MainActor
    @discardableResult
    func launchLive(file: StaticString = #filePath, line: UInt = #line) -> InstalledScreen {
        let app = track(BrewE2EApp.launch())
        return InstalledScreen(app: app)
            .waitUntilLoaded(timeout: BrewE2ETimeout.launch, file: file, line: line)
    }
}
