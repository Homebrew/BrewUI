//
//  BrewE2EApp.swift
//  BrewUITests
//

import XCTest

/// Launches the app with **no** `-uiTesting` argument, which is the whole point: `BrewApp.init()`
/// falls through to `.live()` on both seams, so the login shell resolves, the real `brew` runs, and
/// `URLSession.shared` fetches the real catalogue from formulae.brew.sh. Production wiring, unchanged.
///
/// The only injection is Homebrew's determinism environment (``Brew/determinismEnvironment``).
/// `BrewCommandService` runs the subprocess with `.inherit`, so the variables reach brew through the
/// login shell — a login shell adds to exported variables rather than clearing them. If a dotfile is
/// ever found to stomp one, the fallback is an `-e2e` argument that makes `BrewCommandService` merge
/// these keys into the child environment explicitly (it already conditionally sets env for colour).
@MainActor
enum BrewE2EApp {
    static func launch() -> XCUIApplication {
        let app = XCUIApplication()
        for (key, value) in Brew.determinismEnvironment {
            app.launchEnvironment[key] = value
        }
        app.launch()
        // Same macOS launch/foreground problem the deterministic suite hit; a backgrounded or
        // windowless app has an empty accessibility tree whatever it is wired to.
        BrewApp.activate(app)
        return app
    }
}

/// Live-run timeouts, an order of magnitude above ``BrewUITestTimeout`` because the work behind them
/// is real: a cold `formula.json` is megabytes over the network, and a pour is a download.
///
/// They are generous by design. Off the PR path, the cost of a slow-but-passing run is minutes; the
/// cost of a tight bound is a contract canary that cries wolf about the network.
enum BrewE2ETimeout {
    /// Launch plus the first real `brew info --installed --json=v2` on a populated machine.
    static let launch: TimeInterval = 120
    /// A real download and pour from ghcr.io, plus the inventory reconcile that follows.
    static let install: TimeInterval = 240
    /// Uninstall, plus the reconcile that takes the row away.
    static let uninstall: TimeInterval = 180
    /// A cold catalogue fetch and decode, before search can match anything.
    static let catalogue: TimeInterval = 120
    /// A non-mutating brew run on a real machine — `brew config`, or a forced inventory refresh.
    static let command: TimeInterval = 120
}
