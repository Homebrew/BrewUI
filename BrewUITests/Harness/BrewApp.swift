//
//  BrewApp.swift
//  BrewUITests
//

import AppKit
import BrewUITestContract
import XCTest

/// Launches the app under test against a scenario. The fixture tree travels in the launch environment
/// because both seams are stubbed inside the app process, and a `URLProtocol` registered out here
/// would never see the app's traffic.
@MainActor
enum BrewApp {
    /// The payload compresses well, so approaching this means a fixture grew by an order of magnitude.
    private static let maximumPayloadBytes = 512 * 1024

    /// Asserts nothing about what rendered; the caller decides what "loaded" means for its scenario.
    static func launch(scenario: BrewUITestScenario) throws -> XCUIApplication {
        let encoded = try FakeBrew.payload(for: scenario).encoded()
        guard encoded.utf8.count <= maximumPayloadBytes else {
            throw FakeBrewError.payloadTooLarge(bytes: encoded.utf8.count, limit: maximumPayloadBytes)
        }

        let app = XCUIApplication()
        // The trailing "YES" stops the argument-domain parser swallowing the next argument as a value.
        app.launchArguments += [BrewUITestingEnvironmentKey.launchArgument, "YES"]
        app.launchEnvironment[BrewUITestingEnvironmentKey.scenario] = scenario.rawValue
        app.launchEnvironment[BrewUITestingEnvironmentKey.payload] = encoded
        app.launch()
        activate(app)
        return app
    }

    /// `XCUIApplication` does not expose this, so it is spelled rather than derived.
    private static let appBundleIdentifier = "sh.brew.app"

    /// `launch()` can leave the app frontmost with no window at all, and a windowless app has an empty
    /// accessibility tree. Only the "reopen" AppleEvent a Dock click sends reliably creates one.
    static func activate(_ app: XCUIApplication) {
        app.activate()
        _ = app.wait(for: .runningForeground, timeout: BrewUITestTimeout.launch)
        guard app.windows.count == 0 else { return }
        reopen()
        _ = app.windows.firstMatch.waitForExistence(timeout: BrewUITestTimeout.launch)
    }

    /// `NSWorkspace` rather than `open -b`: a real install with the same bundle identifier would win.
    private static func reopen() {
        guard let target = NSWorkspace.shared.runningApplications
            .filter({ $0.bundleIdentifier == appBundleIdentifier })
            .filter({ $0.executableURL?.path.contains("/DerivedData/") == true })
            .max(by: { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }),
            let bundleURL = target.bundleURL
        else {
            return
        }
        NSWorkspace.shared.open(bundleURL)
    }
}

/// Harness failure, kept distinct from any product error so it never reads as an app problem.
enum FakeBrewError: Error, CustomStringConvertible {
    case payloadTooLarge(bytes: Int, limit: Int)

    var description: String {
        switch self {
        case let .payloadTooLarge(bytes, limit):
            """
            The encoded fixture payload is \(bytes) bytes, over the \(limit)-byte launch-environment \
            budget. Shrink the scenario rather than raising the limit — the environment is shared \
            with everything else the launch needs.
            """
        }
    }
}
