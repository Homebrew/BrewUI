//
//  DoctorOutputParserTests.swift
//  BrewTests
//

import BrewCore
import Foundation
import Testing

struct DoctorOutputParserTests {
    @Test func `healthy output yields no issues`() {
        let report = DoctorOutputParser.parse("Your system is ready to brew.\n")
        #expect(report.isHealthy)
        #expect(report.issues.isEmpty)
    }

    @Test func `empty output is healthy`() {
        #expect(DoctorOutputParser.parse("").isHealthy)
    }

    @Test func `preamble before the first warning is ignored`() {
        let output = """
        Please note that these warnings are just used to help the Homebrew maintainers
        with debugging if you file an issue. Thanks!

        Warning: Something is off.
        Here is why.
        """
        let report = DoctorOutputParser.parse(output)
        #expect(report.issues.count == 1)
        #expect(report.issues.first?.title == "Something is off.")
        #expect(report.issues.first?.details == "Here is why.")
    }

    @Test func `unlinked kegs warning completes the brew link fix with affected items`() throws {
        let output = """
        Warning: You have unlinked kegs in your Cellar.
        Leaving kegs unlinked can lead to build-trouble. Run `brew link` on these:
          openssl@3
          readline
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.title == "You have unlinked kegs in your Cellar.")
        #expect(issue.affectedItems == ["openssl@3", "readline"])
        #expect(issue.suggestedFix?.arguments == ["link", "openssl@3", "readline"])
        #expect(issue.suggestedFix?.displayCommand == "brew link openssl@3 readline")
    }

    @Test func `not-writable directories warning lists paths but has no brew fix`() throws {
        let output = """
        Warning: The following directories are not writable by your user:
        /opt/homebrew
        /opt/homebrew/bin

        You should change the ownership of these directories to your user.
          sudo chown -R me /opt/homebrew /opt/homebrew/bin
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.title == "The following directories are not writable by your user:")
        #expect(issue.affectedItems == ["/opt/homebrew", "/opt/homebrew/bin"])
        #expect(issue.suggestedFix == nil)
    }

    @Test func `verb-only backticked command without items is left as-is`() {
        let output = """
        Warning: Some cached downloads are stale.
        Please run `brew cleanup` to remove them.
        """
        let fix = DoctorOutputParser.parse(output).issues.first?.suggestedFix
        #expect(fix?.arguments == ["cleanup"])
        #expect(fix?.displayCommand == "brew cleanup")
    }

    @Test func `standalone brew command line with explicit targets is used verbatim`() {
        let output = """
        Warning: You should upgrade.
        Run the following:
          brew upgrade git
        """
        let fix = DoctorOutputParser.parse(output).issues.first?.suggestedFix
        #expect(fix?.arguments == ["upgrade", "git"])
        #expect(fix?.displayCommand == "brew upgrade git")
    }

    @Test func `multiple warnings parse in order`() {
        let output = """
        Warning: First problem.
        Detail one.

        Warning: Second problem.
        Detail two.
        """
        let report = DoctorOutputParser.parse(output)
        #expect(report.issues.map(\.title) == ["First problem.", "Second problem."])
        #expect(!report.isHealthy)
    }

    @Test func `warning with only a title has empty details and no items`() {
        let report = DoctorOutputParser.parse("Warning: Lonely warning.")
        let issue = report.issues.first
        #expect(issue?.title == "Lonely warning.")
        #expect(issue?.details == "")
        #expect(issue?.affectedItems.isEmpty == true)
        #expect(issue?.suggestedFix == nil)
    }
}
