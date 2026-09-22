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
/// so the window opens without a saved size. Shrink when wider than its 820-point minimum;
/// otherwise grow so the test still exercises a size change on compact displays.
final class WindowFrameUITests: BrewUITestCase {
    @MainActor
    func testWindowReopensAtTheSizeItWasQuitAt() {
        let first = launch(.empty, environment: [BrewUITestingEnvironmentKey.resetWindowState: "1"]).app
        let window = first.windows.firstMatch
        let initial = window.frame

        let resized = window.resizeWindow(by: CGVector(dx: initial.width > 820 ? -120 : 120, dy: -30))
        XCTAssertNotEqual(resized.size, initial.size, "The drag did not resize the window from \(initial)")

        first.quit()

        let restored = launch(.empty).app.windows.firstMatch.frame
        XCTAssertEqual(restored.width, resized.width, accuracy: 1, "Width was not restored")
        XCTAssertEqual(restored.height, resized.height, accuracy: 1, "Height was not restored")
    }
}
