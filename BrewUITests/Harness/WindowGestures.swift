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

    /// Drags a side edge for width-only changes and a bottom corner otherwise.
    /// Positive deltas grow the window. Returns the settled frame.
    @MainActor
    func resizeWindow(by delta: CGVector, fromLeftEdge: Bool = false) -> CGRect {
        let initial = frame
        // 只改宽度时避开底部 Dock，确保窄窗也能拖回原宽。
        let widthOnly = delta.dy == 0
        let direction: CGFloat = fromLeftEdge ? -1 : 1
        let grip = coordinate(withNormalizedOffset: CGVector(dx: fromLeftEdge ? 0 : 1, dy: widthOnly ? 0.5 : 1))
            .withOffset(CGVector(dx: -direction * Self.resizeGripInset, dy: widthOnly ? 0 : -Self.resizeGripInset))
        let drag = CGVector(dx: direction * delta.dx, dy: delta.dy)
        grip.click(forDuration: 0.3, thenDragTo: grip.withOffset(drag))
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
