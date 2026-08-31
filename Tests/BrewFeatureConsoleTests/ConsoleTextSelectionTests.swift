//
//  ConsoleTextSelectionTests.swift
//  BrewFeatureConsoleTests
//

@testable import BrewFeatureConsole
import Foundation
import Testing

@MainActor
struct ConsoleTextSelectionTests {
    @Test func `a selection inside the document is left alone`() {
        let selection = [NSRange(location: 4, length: 10)]

        #expect(ConsoleTextSelection.clamped(selection, toLength: 40) == selection)
    }

    /// Trimming the front of the buffer shortens the document under the user; the surviving part of the
    /// selection is kept rather than the whole thing being thrown away.
    @Test func `a selection running past the end is clamped to it`() {
        let selection = [NSRange(location: 4, length: 100)]

        #expect(
            ConsoleTextSelection.clamped(selection, toLength: 40) == [NSRange(location: 4, length: 36)],
        )
    }

    @Test func `discontiguous selections are each clamped`() {
        let selection = [NSRange(location: 0, length: 4), NSRange(location: 30, length: 20)]

        #expect(ConsoleTextSelection.clamped(selection, toLength: 40) == [
            NSRange(location: 0, length: 4),
            NSRange(location: 30, length: 10),
        ])
    }

    /// `NSTextView` rejects an empty set of ranges, so a selection that no longer overlaps the document
    /// has to come back as a caret.
    @Test func `a selection entirely past the end collapses to a caret`() {
        let selection = [NSRange(location: 80, length: 20)]

        #expect(
            ConsoleTextSelection.clamped(selection, toLength: 40) == [NSRange(location: 40, length: 0)],
        )
    }

    @Test func `no selection yields a caret at the start`() {
        #expect(ConsoleTextSelection.clamped([], toLength: 40) == [NSRange(location: 0, length: 0)])
    }
}
