//
//  SearchFieldClickAwayTests.swift
//  BrewTests
//

import AppKit
@testable import BrewUIComponents
import Testing

@MainActor
struct SearchFieldClickAwayTests {
    @Test func `a click on the field editor counts as inside the field`() {
        let searchField = NSSearchField()
        let fieldEditor = NSView()
        let clip = NSView()
        searchField.addSubview(clip)
        clip.addSubview(fieldEditor)

        #expect(SearchFieldClickAway.isInsideSearchField(fieldEditor))
    }

    @Test func `a click on the field itself counts as inside it`() {
        #expect(SearchFieldClickAway.isInsideSearchField(NSSearchField()))
    }

    @Test func `a click on a list row counts as outside the field`() {
        let column = NSView()
        let row = NSView()
        column.addSubview(row)

        #expect(!SearchFieldClickAway.isInsideSearchField(row))
    }

    /// A click that hit-tests to nothing (window chrome, the desktop) is not in the field either.
    @Test func `a click on nothing counts as outside the field`() {
        #expect(!SearchFieldClickAway.isInsideSearchField(nil))
    }
}
