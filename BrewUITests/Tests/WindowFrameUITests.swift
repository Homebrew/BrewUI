//
//  WindowFrameUITests.swift
//  BrewUITests
//

import BrewUITestContract
import XCTest

/// The main window comes back at the size the user left it. SwiftUI autosaves the frame under a key
/// derived from the root view's type; a file-private type in that chain once put an ASLR-dependent
/// address in the key, so every launch saved under a fresh name and none found the last one.
///
/// Running this resets the developer's own saved frame once: the app forgets it on the first launch
/// so the window opens at its default size, which it is then shrunk from. Shrinking rather than
/// growing keeps the drag on screen whatever the display size; CI runs at 1024x768.
final class WindowFrameUITests: BrewUITestCase {
    @MainActor
    func testWindowReopensAtTheSizeItWasQuitAt() {
        let first = launch(.empty, environment: [BrewUITestingEnvironmentKey.resetWindowState: "1"]).app
        let window = first.windows.firstMatch
        let initial = window.frame

        let resized = window.resizeWindow(by: CGVector(dx: -120, dy: -30))
        XCTAssertNotEqual(resized.size, initial.size, "The drag did not resize the window from \(initial)")

        first.quit()

        let restoredWindow = launch(.empty).app.windows.firstMatch
        // Content readiness and window restoration can complete at different times.
        let restoredSize = NSPredicate { _, _ in
            let frame = restoredWindow.frame
            return abs(frame.width - resized.width) <= 1 && abs(frame.height - resized.height) <= 1
        }
        let expectation = XCTNSPredicateExpectation(predicate: restoredSize, object: nil)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: BrewUITestTimeout.default),
            .completed,
            "Expected the saved size \(resized.size), got \(restoredWindow.frame.size)",
        )
    }
}
