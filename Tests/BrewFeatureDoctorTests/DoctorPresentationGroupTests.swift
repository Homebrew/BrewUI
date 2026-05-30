//
//  DoctorPresentationGroupTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewFeatureDoctor
import Foundation
import Testing

/// Detail-pane grouping: prose across paragraphs merges into a single "What this means" unless a new
/// paragraph leads with prose **and** the current group already has subject blocks.
@MainActor
struct DoctorPresentationGroupTests {
    @Test func `CLT-shape input collapses to a single group with merged prose`() throws {
        let output = """
        Warning: Your Command Line Tools are too outdated.
        Update them from Software Update in System Settings.

        If that doesn't show you any updates, run:
          sudo rm -rf /Library/Developer/CommandLineTools
          sudo xcode-select --install

        Alternatively, manually download them from:
          https://developer.apple.com/download/all/
        You should download the Command Line Tools for Xcode 26.3.
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        let item = DoctorIssueItem(id: 0, issue: issue)

        #expect(item.presentationGroups.count == 1)
        let group = try #require(item.presentationGroups.first)
        // Both pieces of prose — the leading one and the trailing one — fold into the same group.
        #expect(group.proseLines.contains("Update them from Software Update in System Settings."))
        #expect(group.proseLines.contains("You should download the Command Line Tools for Xcode 26.3."))
        // Subject blocks: one command, one link, in document order.
        #expect(group.subjectBlocks.map(\.type) == [.command, .link])
        #expect(group.subjectBlocks.first?.caption == "If that doesn't show you any updates, run:")
        #expect(group.subjectBlocks.last?.caption == "Alternatively, manually download them from:")
    }

    @Test func `git-status-shape input splits into one group per repo`() throws {
        let output = """
        Warning: You have uncommitted modifications.
        You have uncommitted modifications to Homebrew/homebrew-core.
        To stash these modifications, run:
          git stash -u

        Uncommitted files:
          M  Formula/foo.rb

        You have uncommitted modifications to Homebrew/homebrew-cask.
        To stash these modifications, run:
          git stash -u

        Uncommitted files:
          Cask/baz.rb
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        let item = DoctorIssueItem(id: 0, issue: issue)

        #expect(item.presentationGroups.count == 2)
        let core = try #require(item.presentationGroups.first)
        let cask = try #require(item.presentationGroups.last)
        #expect(core.proseLines.contains { $0.contains("homebrew-core") })
        #expect(cask.proseLines.contains { $0.contains("homebrew-cask") })
        // Each repo gets its own command + its own uncommitted-files data block.
        #expect(core.subjectBlocks.map(\.type) == [.command, .data])
        #expect(cask.subjectBlocks.map(\.type) == [.command, .data])
    }
}
