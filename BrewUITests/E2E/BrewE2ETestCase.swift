//
//  BrewE2ETestCase.swift
//  BrewUITests
//

import XCTest

/// Base class for the live suite. It inherits the deterministic suite's process hygiene — stop on
/// first failure, one app per test, terminated in `tearDown` — and changes exactly one thing: the
/// launch is production wiring against real brew and the real network (``BrewE2EApp``).
///
/// State isolation is split deliberately: tests **arrange and clean up by shelling out** to the real
/// brew (``Brew``), and **act through the UI** using the same page objects the stubbed suite uses.
class BrewE2ETestCase: BrewUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Fail by name, before a launch, on a machine that has no Homebrew — every test here is
        // meaningless without one, and each would otherwise fail slowly and misleadingly.
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
