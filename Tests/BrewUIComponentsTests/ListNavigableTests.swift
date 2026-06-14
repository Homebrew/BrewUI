//
//  ListNavigableTests.swift
//  BrewUIComponentsTests
//

import BrewUIComponents
import Testing

@MainActor
@Suite("ListNavigable clamp behaviour")
struct ListNavigableTests {
    @Test func `select next advances from mid list`() {
        let nav = FakeNavigable(rows: ["a", "b", "c"], selection: "b")
        nav.selectNext()
        #expect(nav.currentSelectionID == "c")
    }

    @Test func `select next clamps at the last row`() {
        let nav = FakeNavigable(rows: ["a", "b", "c"], selection: "c")
        nav.selectNext()
        #expect(nav.currentSelectionID == "c")
    }

    @Test func `select previous moves back from mid list`() {
        let nav = FakeNavigable(rows: ["a", "b", "c"], selection: "b")
        nav.selectPrevious()
        #expect(nav.currentSelectionID == "a")
    }

    @Test func `select previous clamps at the first row`() {
        let nav = FakeNavigable(rows: ["a", "b", "c"], selection: "a")
        nav.selectPrevious()
        #expect(nav.currentSelectionID == "a")
    }

    @Test func `select next without a selection picks the first row`() {
        let nav = FakeNavigable(rows: ["a", "b", "c"], selection: nil)
        nav.selectNext()
        #expect(nav.currentSelectionID == "a")
    }

    @Test func `select previous without a selection picks the last row`() {
        let nav = FakeNavigable(rows: ["a", "b", "c"], selection: nil)
        nav.selectPrevious()
        #expect(nav.currentSelectionID == "c")
    }

    @Test func `select next on an empty list is a no-op`() {
        let nav = FakeNavigable(rows: [], selection: nil)
        nav.selectNext()
        #expect(nav.currentSelectionID == nil)
    }

    @Test func `select previous on an empty list is a no-op`() {
        let nav = FakeNavigable(rows: [], selection: nil)
        nav.selectPrevious()
        #expect(nav.currentSelectionID == nil)
    }

    @Test func `select first picks the first row`() {
        let nav = FakeNavigable(rows: ["a", "b", "c"], selection: "c")
        nav.selectFirst()
        #expect(nav.currentSelectionID == "a")
    }

    @Test func `select last picks the last row`() {
        let nav = FakeNavigable(rows: ["a", "b", "c"], selection: "a")
        nav.selectLast()
        #expect(nav.currentSelectionID == "c")
    }

    @Test func `selection moves across sections because the order is flattened`() {
        // Mirrors the real Installed/Discover pattern: Formulae and Casks sections
        // are concatenated into a single ordered ID list.
        let nav = FakeNavigable(rows: ["formula-1", "formula-2", "cask-1", "cask-2"], selection: "formula-2")
        nav.selectNext()
        #expect(nav.currentSelectionID == "cask-1")
        nav.selectPrevious()
        #expect(nav.currentSelectionID == "formula-2")
    }
}

@MainActor
private final class FakeNavigable: ListNavigable {
    var orderedVisibleRowIDs: [String]
    private(set) var currentSelectionID: String?

    init(rows: [String], selection: String?) {
        orderedVisibleRowIDs = rows
        currentSelectionID = selection
    }

    func setSelection(_ id: String?) {
        currentSelectionID = id
    }
}
