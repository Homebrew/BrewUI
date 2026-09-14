//
//  AnimatedSplitTests.swift
//  BrewTests
//

@testable import BrewUIComponents
import Foundation
import Testing

struct AnimatedSplitTests {
    @Test func `clamped height snaps to the collapsed height when collapsed`() {
        let height = clampedSplitBottomHeight(
            500,
            collapsed: true,
            collapsedHeight: 36,
            minExpanded: 150,
            maxExpanded: 600,
        )

        #expect(height == 36)
    }

    @Test func `clamped expanded height is bounded to the min and max`() {
        func clamp(_ value: CGFloat) -> CGFloat {
            clampedSplitBottomHeight(
                value,
                collapsed: false,
                collapsedHeight: 36,
                minExpanded: 150,
                maxExpanded: 600,
            )
        }

        #expect((clamp(50), clamp(5000), clamp(300)) == (150, 600, 300))
    }
}

struct FittedSplitBottomHeightTests {
    private func fit(_ value: CGFloat, total: CGFloat, collapsed: Bool = false) -> CGFloat {
        fittedSplitBottomHeight(
            value,
            total: total,
            collapsed: collapsed,
            limits: SplitHeightLimits(collapsedHeight: 36, minExpanded: 150, minTop: 360, chrome: 7),
        )
    }

    @Test func `a tall window gives the bottom pane exactly what it asked for`() {
        #expect(fit(250, total: 1000) == 250)
    }

    @Test func `the bottom pane yields so the top keeps its minimum`() {
        // 600 - 7 chrome - 360 top = 233 left for the console, less than the 250 it wanted.
        #expect(fit(250, total: 600) == 233)
    }

    /// The top pane's minimum is a preference, the bottom pane's is a hard floor: below 150 the console
    /// starts rendering artefacts, so it stops yielding and the top takes the rest of the loss.
    @Test func `the bottom pane stops yielding at its own floor`() {
        #expect(fit(250, total: 400) == 150)
    }

    @Test func `a window too short for either pane still lays out inside its bounds`() {
        let height = fit(250, total: 100)
        #expect(height <= 100 - 7)
        #expect(height >= 0)
    }

    /// Nothing is stored per-layout, so growing the window back has to restore the requested height.
    @Test func `growing the window back restores the requested height`() {
        #expect(fit(250, total: 600) == 233)
        #expect(fit(250, total: 1000) == 250)
    }

    @Test func `a collapsed bottom pane keeps its strip height regardless of the top's minimum`() {
        #expect(fit(250, total: 600, collapsed: true) == 36)
        #expect(fit(250, total: 1000, collapsed: true) == 36)
    }

    @Test func `a collapsed strip taller than the window is bounded by it`() {
        #expect(fit(250, total: 20, collapsed: true) == 13)
    }
}
