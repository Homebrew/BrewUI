//
//  BrewE2EApp.swift
//  BrewUITests
//

import XCTest

/// Runs against real Homebrew and the network without `-uiTesting`. Pin the app to English so
/// page-object button queries are independent of the host's per-app language preference.
@MainActor
enum BrewE2EApp {
    static func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)"]
        app.launch()
        BrewApp.activate(app)
        return app
    }
}

/// Live-run timeouts. Generous on purpose: a slow pass costs minutes, a tight bound costs a canary
/// that cries wolf about the network.
enum BrewE2ETimeout {
    /// Launch plus the first real `brew info --installed --json=v2` on a populated machine.
    static let launch: TimeInterval = 120
    /// A download and pour from ghcr.io, plus the inventory reconcile that follows.
    static let install: TimeInterval = 240
    static let uninstall: TimeInterval = 180
    /// A cold catalogue fetch and decode, before search can match anything.
    static let catalogue: TimeInterval = 120
    /// A non-mutating brew run on a real machine — `brew config`, or a forced inventory refresh.
    static let command: TimeInterval = 120
}
