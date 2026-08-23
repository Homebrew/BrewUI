//
//  BrewUITestCase.swift
//  BrewUITests
//

import XCTest

/// Base class for the suite. `continueAfterFailure = false`, or one missing element buries itself in
/// the later failures it causes.
class BrewUITestCase: XCTestCase {
    /// Synchronised by XCTest running setUp, the test and tearDown serially on the main thread.
    // swiftlint:disable:next nonisolated_unsafe
    private nonisolated(unsafe) var launchedApp: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// `launch()` is documented to replace a running instance, but one that went through
    /// ``BrewApp/reopen()`` wedges in the background and fails the next test's launch outright.
    override func tearDown() {
        let app = launchedApp
        launchedApp = nil
        // Always the main thread in practice; the override point just doesn't say so.
        // swiftlint:disable:next assume_isolated
        MainActor.assumeIsolated {
            app?.terminate()
        }
        super.tearDown()
    }

    /// A missing element and a dialog covering the app read identically in text, so failures get a
    /// picture. `keepAlways` keeps the one belonging to a failed attempt of a test that passed on retry.
    override func record(_ issue: XCTIssue) {
        if let screenshot = mainScreenPNG() {
            // PNG data rather than the `XCUIScreenshot`, which cannot cross out of the main actor.
            let attachment = XCTAttachment(data: screenshot, uniformTypeIdentifier: "public.png")
            attachment.name = "Failure: \(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        super.record(issue)
    }

    /// Off the main thread the failure goes unillustrated rather than risking a crash inside `record`.
    private func mainScreenPNG() -> Data? {
        guard Thread.isMainThread else {
            return nil
        }
        // swiftlint:disable:next assume_isolated
        return MainActor.assumeIsolated {
            XCUIScreen.main.screenshot().pngRepresentation
        }
    }

    /// For an app the case launched itself — the live suite — so `tearDown` terminates that one too.
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
