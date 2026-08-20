//
//  BrewE2EApp.swift
//  BrewUITests
//

import XCTest

/// Launches the app with **no** `-uiTesting` argument, so `BrewApp.init()` falls through to `.live()`
/// on both seams: real login shell, real `brew`, real `URLSession.shared`.
///
/// The only injection is ``Brew/determinismEnvironment``. `BrewCommandService` inherits the process
/// environment, and a login shell adds to exported variables rather than clearing them, so those
/// survive `-l -i`.
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

/// Live-run timeouts, an order of magnitude above ``BrewUITestTimeout`` because the work behind them
/// is real. Generous on purpose: off the PR path a slow pass costs minutes, while a tight bound costs
/// a canary that cries wolf about the network.
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
