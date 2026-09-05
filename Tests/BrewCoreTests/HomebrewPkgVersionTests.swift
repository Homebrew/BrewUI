//
//  HomebrewPkgVersionTests.swift
//  BrewTests
//

import BrewCore
import Foundation
import Testing

struct HomebrewPkgVersionTests {
    @Test func `revision zero renders the bare version`() {
        #expect(HomebrewPkgVersion.string(version: "9.0.1", revision: 0) == "9.0.1")
    }

    @Test func `missing revision renders the bare version`() {
        #expect(HomebrewPkgVersion.string(version: "9.0.1", revision: nil) == "9.0.1")
    }

    @Test func `non zero revision is appended with an underscore`() {
        #expect(HomebrewPkgVersion.string(version: "9.0.1", revision: 1) == "9.0.1_1")
        #expect(HomebrewPkgVersion.string(version: "1.11.1", revision: 4) == "1.11.1_4")
    }

    @Test func `version is trimmed before the revision is appended`() {
        #expect(HomebrewPkgVersion.string(version: "  3.8.13\n", revision: 2) == "3.8.13_2")
    }

    @Test func `missing or blank versions yield nil regardless of revision`() {
        #expect(HomebrewPkgVersion.string(version: nil, revision: 1) == nil)
        #expect(HomebrewPkgVersion.string(version: "", revision: 1) == nil)
        #expect(HomebrewPkgVersion.string(version: "   ", revision: 0) == nil)
    }

    @Test func `negative revisions are ignored rather than rendered`() {
        #expect(HomebrewPkgVersion.string(version: "9.0.1", revision: -1) == "9.0.1")
    }
}
