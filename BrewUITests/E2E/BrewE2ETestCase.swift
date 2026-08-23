//
//  BrewE2ETestCase.swift
//  BrewUITests
//

import XCTest

/// Base class for the live suite: ``BrewUITestCase``'s process hygiene, with ``BrewE2EApp``'s
/// production wiring in place of the stubbed launch.
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
