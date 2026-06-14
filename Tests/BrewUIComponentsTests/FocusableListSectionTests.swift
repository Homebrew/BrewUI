//
//  FocusableListSectionTests.swift
//  BrewUIComponentsTests
//

import BrewUIComponents
import Testing

@Suite("FocusableListSection traversal")
struct FocusableListSectionTests {
    @Test func `next advances to the following row in mid list`() {
        let advance = nextFocus(after: "b", in: ["a", "b", "c"], canExpand: false)
        #expect(advance == .move("c"))
    }

    @Test func `next on the last row clamps when section cannot expand`() {
        let advance = nextFocus(after: "c", in: ["a", "b", "c"], canExpand: false)
        #expect(advance == .stay)
    }

    @Test func `next on the last row signals expand when section can expand`() {
        let advance = nextFocus(after: "c", in: ["a", "b", "c"], canExpand: true)
        #expect(advance == .expand)
    }

    @Test func `next without focus picks the first row`() {
        let advance = nextFocus(after: nil as String?, in: ["a", "b", "c"], canExpand: false)
        #expect(advance == .move("a"))
    }

    @Test func `next on an empty section is a no-op`() {
        let advance = nextFocus(after: nil as String?, in: [] as [String], canExpand: true)
        #expect(advance == .stay)
    }

    @Test func `next when current id is not in the section picks the first row`() {
        // Defensive: if the focused id stopped being part of the visible set, recover to the top.
        let advance = nextFocus(after: "zebra", in: ["a", "b", "c"], canExpand: false)
        #expect(advance == .move("a"))
    }

    @Test func `previous walks back from mid list`() {
        let advance = previousFocus(before: "b", in: ["a", "b", "c"])
        #expect(advance == .move("a"))
    }

    @Test func `previous on the first row clamps`() {
        let advance = previousFocus(before: "a", in: ["a", "b", "c"])
        #expect(advance == .stay)
    }

    @Test func `previous without focus picks the last row`() {
        let advance = previousFocus(before: nil as String?, in: ["a", "b", "c"])
        #expect(advance == .move("c"))
    }

    @Test func `previous on an empty section is a no-op`() {
        let advance = previousFocus(before: nil as String?, in: [] as [String])
        #expect(advance == .stay)
    }
}
