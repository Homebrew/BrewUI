//
//  FocusSearchFieldActionTests.swift
//  BrewTests
//

@testable import BrewUIComponents
import Foundation
import Testing

/// ⌘F used to publish a `Binding<Bool>` that the command set to `true`. Writing `true` over an
/// already-`true` binding is not a state change, so the second and later presses did nothing —
/// which is the whole reason this is an action. These pin that difference.
@MainActor
struct FocusSearchFieldActionTests {
    @Test func `invoking the action runs its handler`() {
        var runs = 0
        let action = FocusSearchFieldAction { runs += 1 }

        action()

        #expect(runs == 1)
    }

    @Test func `repeat invocations each run the handler`() {
        var runs = 0
        let action = FocusSearchFieldAction { runs += 1 }

        action()
        action()
        action()

        #expect(runs == 3)
    }

    /// The panes drive focus state the user can move out from under them (clicking the list, ⎋).
    /// Each invocation must therefore act on the state as it stands, not on a snapshot taken when
    /// the action was published.
    @Test func `the handler re-reads the state it drives on every invocation`() {
        var focused = false
        let action = FocusSearchFieldAction { focused = true }

        action()
        #expect(focused)

        focused = false // the user clicked away
        action()

        #expect(focused)
    }
}
