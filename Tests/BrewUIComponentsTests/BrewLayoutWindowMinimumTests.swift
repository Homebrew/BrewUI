//
//  BrewLayoutWindowMinimumTests.swift
//  BrewUIComponentsTests
//

@testable import BrewUIComponents
import Foundation
import Testing

/// The window minimum and the split's two floors have to agree, or the smallest window starves a pane.
struct BrewLayoutWindowMinimumTests {
    private static let chrome = AnimatedSplitView.handleThickness + AnimatedSplitView.dividerThickness

    private static let limits = SplitHeightLimits(
        collapsedHeight: BrewLayout.consoleCollapsedHeight,
        minExpanded: BrewLayout.consoleMinExpandedHeight,
        minTop: BrewLayout.mainPaneMinHeight,
        chrome: chrome,
    )

    /// What the console actually opens at in a window of `total`, having yielded whatever it must.
    private static func consoleOpensAt(windowHeight total: CGFloat) -> CGFloat {
        fittedSplitBottomHeight(
            BrewLayout.consoleDefaultExpandedHeight,
            total: total,
            collapsed: false,
            limits: limits,
        )
    }

    private static func mainPane(windowHeight total: CGFloat) -> CGFloat {
        total - chrome - consoleOpensAt(windowHeight: total)
    }

    @Test func `the smallest window fits the console's floor and the main pane's together`() {
        let available = BrewLayout.minWindowHeight - Self.chrome
        #expect(available - BrewLayout.consoleMinExpandedHeight >= BrewLayout.mainPaneMinHeight)
    }

    /// The point of sizing the minimum against the console's floor rather than its default height.
    @Test func `a short window opens the console at its floor, not its default`() {
        #expect(Self.consoleOpensAt(windowHeight: BrewLayout.minWindowHeight)
            < BrewLayout.consoleDefaultExpandedHeight)
        #expect(Self.consoleOpensAt(windowHeight: BrewLayout.minWindowHeight)
            >= BrewLayout.consoleMinExpandedHeight)
    }

    /// Whatever it opens at, the pane above keeps its floor — that is what the yielding is for.
    @Test func `the main pane keeps its floor at every window height from the minimum up`() {
        for total in stride(from: BrewLayout.minWindowHeight, through: 1400, by: 20) {
            #expect(Self.mainPane(windowHeight: total) >= BrewLayout.mainPaneMinHeight)
        }
    }

    @Test func `a window with the room for it opens the console at its usual height`() {
        let roomy = BrewLayout.mainPaneMinHeight
            + BrewLayout.consoleDefaultExpandedHeight
            + Self.chrome
        #expect(Self.consoleOpensAt(windowHeight: roomy) == BrewLayout.consoleDefaultExpandedHeight)
    }

    @Test func `a collapsed console leaves the main pane far above its floor`() {
        let available = BrewLayout.minWindowHeight - AnimatedSplitView.dividerThickness
        #expect(available - BrewLayout.consoleCollapsedHeight >= BrewLayout.mainPaneMinHeight)
    }
}
