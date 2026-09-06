//
//  BrewE2EApp.swift
//  BrewUITests
//

import XCTest

/// Launches with **no** `-uiTesting` argument, so `BrewApp.init()` takes `.live()`: real login shell,
/// real `brew`, real network. The injected determinism environment survives `-l -i` because a login
/// shell adds to exported variables rather than clearing them.
@MainActor
enum BrewE2EApp {
    static func launch() -> XCUIApplication {
        let app = XCUIApplication()
        for (key, value) in Brew.determinismEnvironment {
            app.launchEnvironment[key] = value
        }
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
