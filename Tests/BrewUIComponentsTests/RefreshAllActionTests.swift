//
//  RefreshAllActionTests.swift
//  BrewTests
//

@testable import BrewUIComponents
import Foundation
import Testing

@MainActor
struct RefreshAllActionTests {
    @Test func `invoking the action runs its handler`() {
        var runs = 0
        let action = RefreshAllAction { runs += 1 }

        action()

        #expect(runs == 1)
    }

    @Test func `every ⌘R runs the handler again`() {
        var runs = 0
        let action = RefreshAllAction { runs += 1 }

        action()
        action()
        action()

        #expect(runs == 3)
    }

    @Test func `the handler re-reads the state it refreshes on every invocation`() {
        var refreshed: [String] = []
        var surfaces = ["installed", "discover"]
        let action = RefreshAllAction { refreshed.append(contentsOf: surfaces) }

        action()
        #expect(refreshed == ["installed", "discover"])

        surfaces = ["config"]
        action()

        #expect(refreshed == ["installed", "discover", "config"])
    }
}
