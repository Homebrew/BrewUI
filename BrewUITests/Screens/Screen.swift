//
//  Screen.swift
//  BrewUITests
//

import BrewAccessibilityID
import XCTest

/// One type per surface. Actions return the screen they navigate to, so an illegal sequence fails to
/// compile rather than at runtime.
@MainActor
protocol Screen {
    var app: XCUIApplication { get }
    /// Proves the screen is up. Navigation waits on it, so tests need no wait of their own.
    var root: BrewUIElement { get }
}

extension Screen {
    @discardableResult
    func waitUntilLoaded(
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        root.waitToExist(timeout: timeout, file: file, line: line)
        return self
    }

    var sidebar: Sidebar {
        Sidebar(app: app)
    }

    var console: ConsoleScreen {
        ConsoleScreen(app: app)
    }

    /// Scoped to this screen's root, so a Discover failure cannot be satisfied by an Installed one.
    var errorState: BrewUIStaticText {
        BrewUIStaticText(app, .errorState, in: root.element)
    }

    @discardableResult
    func assertShowsErrorState(
        timeout: TimeInterval = BrewUITestTimeout.default,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        errorState.waitToExist(timeout: timeout, file: file, line: line)
        return self
    }

    @discardableResult
    func assertShowsNoErrorState(
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        errorState.assertDoesNotExist(file: file, line: line)
        return self
    }

    @discardableResult
    func retry(
        file: StaticString = #filePath,
        line: UInt = #line,
    ) -> Self {
        BrewUIButton(app, .errorRetryButton, in: root.element).tap(file: file, line: line)
        return self
    }
}
