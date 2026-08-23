//
//  BrewUITestCase.swift
//  BrewUITests
//

import XCTest

/// Base class for the suite. `continueAfterFailure = false` matters more here than in a unit suite:
/// once an element is missing every later step in a chain fails too, burying the one that explains it.
class BrewUITestCase: XCTestCase {
    /// XCTest calls `setUp`/the test body/`tearDown` serially on the main thread, but none of those
    /// override points are themselves `@MainActor` — the annotation below records that this is
    /// manually synchronised by that ordering rather than by the type system.
    // swiftlint:disable:next nonisolated_unsafe
    private nonisolated(unsafe) var launchedApp: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// `launch()` is documented to replace a running instance of the same bundle, but that proved
    /// unreliable once a prior launch went through ``BrewApp/reopen()``: the next test finds the old
    /// process wedged in the background and fails outright. Ending on a clean process list avoids it.
    override func tearDown() {
        let app = launchedApp
        launchedApp = nil
        // XCTest always calls tearDown() on the main thread in practice, it just doesn't say so in
        // the override point's signature — asserted here rather than provable at compile time.
        // swiftlint:disable:next assume_isolated
        MainActor.assumeIsolated {
            app?.terminate()
        }
        super.tearDown()
    }

    /// Attaches what the screen looked like at the moment of the failure, which is the one thing the
    /// message cannot carry: a missing element and a dialog covering the app read identically in
    /// text. `keepAlways` so the shot survives a plan that prunes on success, which is what a retried
    /// test's failed attempt would otherwise be pruned by.
    ///
    /// An issue recorded off the main thread goes unillustrated rather than risking a crash inside
    /// the failure path; every assertion in the suite runs on the main thread.
    override func record(_ issue: XCTIssue) {
        if let screenshot = mainScreenPNG() {
            // Attached as PNG data rather than as the `XCUIScreenshot`, which cannot cross out of the
            // main actor: `add(_:)` belongs to this nonisolated test case, `Data` is sendable.
            let attachment = XCTAttachment(data: screenshot, uniformTypeIdentifier: "public.png")
            attachment.name = "Failure: \(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        super.record(issue)
    }

    private func mainScreenPNG() -> Data? {
        guard Thread.isMainThread else {
            return nil
        }
        // swiftlint:disable:next assume_isolated
        return MainActor.assumeIsolated {
            XCUIScreen.main.screenshot().pngRepresentation
        }
    }

    /// Registers an app the case launched for itself — the live suite in `BrewUITests/E2E` — so
    /// `tearDown` terminates it exactly as ``launch(_:file:line:)`` does.
    @discardableResult
    func track(_ app: XCUIApplication) -> XCUIApplication {
        launchedApp = app
        return app
    }

    /// Launches against `scenario` and returns the Installed tab, waited for.
    @MainActor
    @discardableResult
    func launch(
        _ scenario: BrewUITestScenario,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> InstalledScreen {
        let app = launchUnverified(scenario, file: file, line: line)
        return InstalledScreen(app: app).waitUntilLoaded(timeout: BrewUITestTimeout.launch, file: file, line: line)
    }

    /// For scenarios whose point is that the Installed tab cannot render.
    @MainActor
    @discardableResult
    func launchUnverified(
        _ scenario: BrewUITestScenario,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> XCUIApplication {
        do {
            let app = try BrewApp.launch(scenario: scenario)
            launchedApp = app
            return app
        } catch {
            XCTFail("Could not launch \(scenario.rawValue): \(error)", file: file, line: line)
            return XCUIApplication()
        }
    }
}
