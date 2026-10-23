//
//  CleanupOutputParserTests.swift
//  BrewTests
//

import BrewCore
import BrewRepositories
import Foundation
import Testing

struct CleanupOutputParserTests {
    /// Captured from `brew cleanup --dry-run` on Homebrew 7.0.10, with an autoremove block added in
    /// the shape `Cleanup.autoremove` prints it.
    private static let output = """
    ==> Would autoremove 2 unneeded formulae:
    libyaml
    homebrew/core/m4
    Would remove: /Users/me/Library/Caches/Homebrew/portable-ruby-4.0.7.arm64_big_sur.bottle.tar.gz (12.7MB)
    Would remove: /Users/me/Library/Caches/Homebrew/bootsnap/1648b9c0 (815 files, 7.4MB)
    Would remove (broken link): /opt/homebrew/bin/old-tool
    Would remove (empty directory): /opt/homebrew/share/old-tool
    ==> This operation would free approximately 67.5MB of disk space.
    """

    @Test func `lists the formulae autoremove would uninstall`() {
        let report = CleanupOutputParser.parse(Self.output, pruneAll: false)
        #expect(report.unneededFormulae == ["libyaml", "homebrew/core/m4"])
    }

    @Test func `lists every path in output order with its kind and size`() {
        let report = CleanupOutputParser.parse(Self.output, pruneAll: false)
        #expect(report.removals == [
            CleanupRemoval(
                path: "/Users/me/Library/Caches/Homebrew/portable-ruby-4.0.7.arm64_big_sur.bottle.tar.gz",
                kind: .file,
                size: "12.7MB",
            ),
            CleanupRemoval(path: "/Users/me/Library/Caches/Homebrew/bootsnap/1648b9c0", kind: .file, size: "815 files, 7.4MB"),
            CleanupRemoval(path: "/opt/homebrew/bin/old-tool", kind: .brokenLink),
            CleanupRemoval(path: "/opt/homebrew/share/old-tool", kind: .emptyDirectory),
        ])
    }

    @Test func `keeps Homebrew's own total`() {
        let report = CleanupOutputParser.parse(Self.output, pruneAll: false)
        #expect(report.reclaimableSpace == "67.5MB")
    }

    @Test func `records which option produced the report`() {
        #expect(CleanupOutputParser.parse(Self.output, pruneAll: true).pruneAll)
    }

    @Test func `a path containing parentheses keeps them`() {
        let report = CleanupOutputParser.parse("Would remove: /tmp/App (Beta).dmg (3MB)\n", pruneAll: false)
        #expect(report.removals == [CleanupRemoval(path: "/tmp/App (Beta).dmg", kind: .file, size: "3MB")])
    }

    @Test func `strips colour before parsing`() {
        let coloured = "\u{1B}[34m==>\u{1B}[0m \u{1B}[1mThis operation would free approximately 1.2GB of disk space.\u{1B}[0m\n"
        #expect(CleanupOutputParser.parse(coloured, pruneAll: false).reclaimableSpace == "1.2GB")
    }

    @Test func `empty output is an empty report`() {
        let report = CleanupOutputParser.parse("", pruneAll: false)
        #expect(report.isEmpty && report.reclaimableSpace == nil)
    }

    @Test func `unrecognised lines are ignored rather than misread`() {
        let output = """
        Warning: Skipping old-tool: most recent version 2.0 not installed
        ==> Would autoremove 1 unneeded formula:
        libyaml

        Some future line Homebrew might print
        """
        let report = CleanupOutputParser.parse(output, pruneAll: false)
        #expect(report == CleanupReport(pruneAll: false, unneededFormulae: ["libyaml"], removals: [], reclaimableSpace: nil, rawOutput: output))
    }
}
