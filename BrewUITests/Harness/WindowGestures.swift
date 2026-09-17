//
//  WindowGestures.swift
//  BrewUITests
//

import XCTest

extension XCUIApplication {
    /// ⌘Q rather than `terminate()`: what a normal quit leaves behind is what the next launch restores.
    @MainActor
    func quit(file: StaticString = #filePath, line: UInt = #line) {
        typeKey("q", modifierFlags: .command)
        XCTAssertTrue(
            wait(for: .notRunning, timeout: BrewUITestTimeout.default),
            "The app did not quit",
            file: file,
            line: line,
        )
    }
}

extension XCUIElement {
    /// A click exactly on the edge, or outside it, starts no resize; a few points inside does.
    private static let resizeGripInset: CGFloat = 3

    /// Drags this window's bottom-right corner by `delta` and returns the frame it settled at. Compare
    /// against `frame` beforehand to know whether anything moved. Prefer a negative delta: a default-size
    /// window can always shrink, whereas growing needs screen room a 1024x768 CI display does not have.
    @MainActor
    func resizeWindow(by delta: CGVector) -> CGRect {
        let initial = frame
        let grip = coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
            .withOffset(CGVector(dx: -Self.resizeGripInset, dy: -Self.resizeGripInset))
        grip.click(forDuration: 0.3, thenDragTo: grip.withOffset(delta))
        return waitForFrameToSettle(differingFrom: initial)
    }

    /// A live resize reports intermediate frames; wait for one that has changed and then stopped moving.
    @MainActor
    private func waitForFrameToSettle(differingFrom initial: CGRect) -> CGRect {
        let deadline = Date().addingTimeInterval(BrewUITestTimeout.default)
        var last = frame
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            let current = frame
            if current != initial, current == last {
                return current
            }
            last = current
        }
        return last
    }
}
