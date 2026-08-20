//
//  FocusSearchFieldActionTests.swift
//  BrewTests
//

@testable import BrewUIComponents
import Foundation
import Testing

/// Repeat presses are the point: the `Binding<Bool>` this replaced went dead once it was `true`.
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
