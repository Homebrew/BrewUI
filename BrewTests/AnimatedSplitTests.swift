//
//  AnimatedSplitTests.swift
//  BrewTests
//

@testable import Brew
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
