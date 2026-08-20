//
//  BrewApp.swift
//  BrewUITests
//

import AppKit
import BrewUITestContract
import XCTest

/// Launches the app under test against a scenario.
///
/// Both seams are stubbed *inside the app process*: a `URLProtocol` registered here would run in the
/// test process and never see the app's traffic, and this process cannot rely on writing anywhere the
/// app is allowed to execute from. So the fixture tree travels in the launch environment instead.
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
        // The trailing "YES" keeps `NSUserDefaults`' argument-domain parser from swallowing whatever
        // launch argument comes next as this flag's value.
        app.launchArguments += [BrewUITestingEnvironmentKey.launchArgument, "YES"]
        app.launchEnvironment[BrewUITestingEnvironmentKey.scenario] = scenario.rawValue
        app.launchEnvironment[BrewUITestingEnvironmentKey.payload] = encoded
        app.launch()
        activate(app)
        return app
    }

    /// `XCUIApplication` does not expose this, so it is spelled rather than derived.
    private static let appBundleIdentifier = "sh.brew.app"

    /// `launch()` can leave the app frontmost with a populated menu bar and no window at all, and a
    /// windowless app has an empty accessibility tree — so every query fails for a reason unrelated to
    /// what it asked for. Only the "reopen" AppleEvent a Dock click sends reliably creates the window.
    ///
    /// Not private: ``BrewE2EApp`` launches its own app and hits the same macOS behaviour.
    static func activate(_ app: XCUIApplication) {
        app.activate()
        _ = app.wait(for: .runningForeground, timeout: BrewUITestTimeout.launch)
        guard app.windows.count == 0 else { return }
        reopen()
        _ = app.windows.firstMatch.waitForExistence(timeout: BrewUITestTimeout.launch)
    }

    /// `NSWorkspace` rather than `open -b`, which resolves by bundle identifier alone: a developer
    /// machine may have a real install carrying the same identifier, and reopening *that* would steal
    /// focus from the build under test. Matching the executable path keeps it on the right instance.
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
