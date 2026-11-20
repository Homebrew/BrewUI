//
//  WindowFrameUITests.swift
//  BrewUITests
//

import AppKit
import BrewUITestContract
import XCTest

/// The main window comes back at the size the user left it. SwiftUI autosaves the frame under a key
/// derived from the root view's type; a file-private type in that chain once put an ASLR-dependent
/// address in the key, so every launch saved under a fresh name and none found the last one.
///
/// Requests a fresh frame on the first launch, but does not assume a particular starting size.
final class WindowFrameUITests: BrewUITestCase {
    @MainActor
    func testWindowReopensAtTheSizeItWasQuitAt() throws {
        let first = launch(.empty, environment: [BrewUITestingEnvironmentKey.resetWindowState: "1"]).app
        let window = first.windows.firstMatch
        let initial = window.frame

        let resized = try resizeWidth(of: window, from: initial)
        XCTAssertNotEqual(resized.width, initial.width, "The drag did not resize the window from \(initial)")

        first.quit()

        // 重开应恢复窗口，而不是再次清除已保存的尺寸。
        first.launchEnvironment.removeValue(forKey: BrewUITestingEnvironmentKey.resetWindowState)
        first.launch()
        BrewApp.activate(first)
        InstalledScreen(app: first).waitUntilLoaded(timeout: BrewUITestTimeout.launch)
        let restored = first.windows.firstMatch.frame
        XCTAssertEqual(restored.width, resized.width, accuracy: 1, "Width was not restored")
        XCTAssertEqual(restored.height, resized.height, accuracy: 1, "Height was not restored")
    }

    @MainActor
    private func resizeWidth(of window: XCUIElement, from initial: CGRect) throws -> CGRect {
        let minimumWidth: CGFloat = 820
        let resizeStep: CGFloat = 120
        let shrink = min(resizeStep, initial.width - minimumWidth)
        if shrink > 1 {
            return window.resizeWindow(by: CGVector(dx: -shrink, dy: 0))
        }

        let display = try XCTUnwrap(NSScreen.main?.visibleFrame)
        let roomOnLeft = initial.minX - display.minX
        let roomOnRight = display.maxX - initial.maxX
        let growth = min(resizeStep, max(roomOnLeft, roomOnRight))
        XCTAssertGreaterThan(growth, 1, "No room to resize the \(initial.width)pt window on \(display)")
        return window.resizeWindow(by: CGVector(dx: growth, dy: 0), fromLeftEdge: roomOnLeft > roomOnRight)
    }
}
