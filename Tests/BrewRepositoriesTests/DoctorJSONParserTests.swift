//
//  DoctorJSONParserTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewRepositories
import Foundation
import Testing

/// Fixtures are copied from a real `brew doctor --json` run (Homebrew 6.0.22), trailing newlines and
/// inconsistent indentation included, so the parser is held to what brew actually emits.
struct DoctorJSONParserTests {
    private static func parse(_ json: String) throws -> [DoctorIssue] {
        try DoctorJSONParser.parse(Data(json.utf8))
    }

    // MARK: - Shape

    @Test func `each finding becomes one issue`() throws {
        let issues = try Self.parse("""
        {
          "tier": 1,
          "findings": [
            { "text": "Some installed casks are deprecated or disabled.", "tier": 1,
              "affects": ["rar"], "links": [],
              "remediation": { "commands": [],
                "text": "You should find replacements for the following casks:\\nrar\\n" } },
            { "text": "Your Command Line Tools are too outdated.\\n", "tier": 1,
              "affects": [], "links": [], "remediation": null }
          ]
        }
        """)

        #expect(issues.count == 2)
        #expect(issues[0].title == "Some installed casks are deprecated or disabled.")
        #expect(issues[1].title == "Your Command Line Tools are too outdated.")
    }

    @Test func `an empty findings array is a healthy system`() throws {
        #expect(try Self.parse(#"{"tier": 1, "findings": []}"#).isEmpty)
    }

    @Test func `remediation text becomes part of the issue body`() throws {
        let issues = try Self.parse("""
        {
          "tier": 1,
          "findings": [
            { "text": "The staging path /opt/homebrew/Caskroom is not writable by the current user.\\n",
              "tier": 1, "affects": [], "links": [],
              "remediation": { "commands": ["sudo chown -R me /opt/homebrew/Caskroom"],
                "text": "To fix, run:\\n  sudo chown -R me /opt/homebrew/Caskroom\\n" } }
          ]
        }
        """)

        let issue = try #require(issues.first)
        #expect(issue.title == "The staging path /opt/homebrew/Caskroom is not writable by the current user.")
        #expect(issue.rawBody.contains("To fix, run:"))
        #expect(commandLines(in: issue) == ["sudo chown -R me /opt/homebrew/Caskroom"])
    }

    /// Mirrors brew's own `Remediation#to_s` fallback for a finding whose only remediation is commands.
    @Test func `commands with no remediation text are introduced the way brew introduces them`() throws {
        let issues = try Self.parse("""
        {
          "tier": 1,
          "findings": [
            { "text": "You have unlinked kegs in your Cellar.", "tier": 1, "affects": [], "links": [],
              "remediation": { "commands": ["brew link openssl@3"], "text": "" } }
          ]
        }
        """)

        let issue = try #require(issues.first)
        #expect(issue.rawBody.contains("You can solve this by running:"))
        #expect(commandLines(in: issue) == ["brew link openssl@3"])
    }

    // MARK: - Severity

    @Test func `support tier maps onto severity`() throws {
        let issues = try Self.parse("""
        {
          "tier": "unsupported",
          "findings": [
            { "text": "A.", "tier": 1, "affects": [], "links": [], "remediation": null },
            { "text": "B.", "tier": 2, "affects": [], "links": [], "remediation": null },
            { "text": "C.", "tier": 3, "affects": [], "links": [], "remediation": null },
            { "text": "D.", "tier": "unsupported", "affects": [], "links": [], "remediation": null }
          ]
        }
        """)

        #expect(issues.map(\.severity) == [.caution, .caution, .danger, .unsupported])
    }

    @Test func `an unrecognised tier reads as the mildest severity`() throws {
        let issues = try Self.parse("""
        {"tier": 1, "findings": [
          { "text": "A.", "tier": "brand-new-tier", "affects": [], "links": [], "remediation": null }
        ]}
        """)

        #expect(issues.first?.severity == .caution)
    }

    // MARK: - Runnable commands

    /// The plan's central safety rule: a command line that only appears in the free text is copy-only,
    /// however runnable it looks. brew leaves destructive steps out of `commands` on purpose.
    @Test func `a command only in the remediation text is never runnable`() throws {
        let issues = try Self.parse("""
        {
          "tier": 1,
          "findings": [
            { "text": "Your Command Line Tools are too outdated.\\n", "tier": 1, "affects": [], "links": [],
              "remediation": { "commands": [],
                "text": "If that doesn't show you any updates, run:\\n  brew update --force\\n" } }
          ]
        }
        """)

        let issue = try #require(issues.first)
        #expect(commandLines(in: issue) == ["brew update --force"])
        #expect(runnableArguments(in: issue).isEmpty)
    }

    @Test func `a brew command listed in commands stays runnable`() throws {
        let issues = try Self.parse("""
        {
          "tier": 1,
          "findings": [
            { "text": "You have unlinked kegs in your Cellar.", "tier": 1, "affects": [], "links": [],
              "remediation": { "commands": ["brew link openssl@3"],
                "text": "To fix, run:\\n  brew link openssl@3\\n" } }
          ]
        }
        """)

        #expect(try runnableArguments(in: #require(issues.first)) == [["link", "openssl@3"]])
    }

    @Test func `a sudo command listed in commands is still copy-only`() throws {
        let issues = try Self.parse("""
        {
          "tier": 1,
          "findings": [
            { "text": "The staging path is not writable.", "tier": 1, "affects": [], "links": [],
              "remediation": { "commands": ["sudo chown -R me /opt/homebrew/Caskroom"],
                "text": "To fix, run:\\n  sudo chown -R me /opt/homebrew/Caskroom\\n" } }
          ]
        }
        """)

        #expect(try runnableArguments(in: #require(issues.first)).isEmpty)
    }

    // MARK: - affects / links

    @Test func `affects the body already lists are not repeated`() throws {
        let issues = try Self.parse("""
        {
          "tier": 1,
          "findings": [
            { "text": "Some installed casks are deprecated or disabled.", "tier": 1,
              "affects": ["rar"], "links": [],
              "remediation": { "commands": [],
                "text": "You should find replacements for the following casks:\\nrar\\n" } }
          ]
        }
        """)

        let issue = try #require(issues.first)
        #expect(issue.blocks.filter { $0.caption == "Affects:" }.isEmpty)
        #expect(issue.rawBody.contains("rar"))
    }

    @Test func `affects the body never mentions are surfaced`() throws {
        let issues = try Self.parse("""
        {"tier": 1, "findings": [
          { "text": "Some installed formulae are deprecated or disabled.", "tier": 1,
            "affects": ["periphery"], "links": [], "remediation": null }
        ]}
        """)

        let issue = try #require(issues.first)
        #expect(dataItems(in: issue) == ["periphery"])
    }

    @Test func `links the body never mentions are surfaced`() throws {
        let issues = try Self.parse("""
        {"tier": 1, "findings": [
          { "text": "This is an unsupported configuration.", "tier": "unsupported",
            "affects": [], "links": ["https://docs.brew.sh/Support-Tiers"], "remediation": null }
        ]}
        """)

        let issue = try #require(issues.first)
        let links = issue.blocks.flatMap { block -> [DoctorLink] in
            guard case let .link(links) = block.content else { return [] }
            return links
        }
        #expect(links.map(\.url.absoluteString) == ["https://docs.brew.sh/Support-Tiers"])
    }

    // MARK: - Hostile input

    @Test func `ANSI escapes inside JSON strings never reach the model`() throws {
        let issues = try Self.parse("""
        {"tier": 1, "findings": [
          { "text": "Homebrew's origin is not set.", "tier": 1, "affects": [], "links": [],
            "remediation": { "commands": [],
              "text": "Run:\\n  git remote add origin \\u001b[4mhttps://github.com/Homebrew/brew\\u001b[24m\\n" } }
        ]}
        """)

        let issue = try #require(issues.first)
        #expect(!issue.rawBody.contains("\u{1B}"))
        #expect(issue.rawBody.contains("https://github.com/Homebrew/brew"))
    }

    @Test func `missing keys fall back to empty rather than failing the report`() throws {
        let issues = try Self.parse(#"{"findings": [{"text": "Something is off."}]}"#)

        #expect(issues.count == 1)
        #expect(issues[0].severity == .caution)
        #expect(issues[0].blocks.isEmpty)
    }

    @Test func `unknown keys are ignored`() throws {
        let issues = try Self.parse("""
        {"tier": 1, "schema_version": 2, "findings": [
          {"text": "Something is off.", "tier": 1, "affects": [], "links": [],
           "remediation": null, "check": "check_something"}
        ]}
        """)

        #expect(issues.count == 1)
    }

    @Test func `a finding with no text is dropped rather than shown blank`() throws {
        #expect(try Self.parse(#"{"tier": 1, "findings": [{"text": "  ", "tier": 1}]}"#).isEmpty)
    }

    @Test func `output that is not this command's JSON throws`() {
        #expect(throws: (any Error).self) {
            try Self.parse("Error: invalid option: --json")
        }
    }

    // MARK: - Helpers

    private func commandLines(in issue: DoctorIssue) -> [String] {
        issue.blocks.flatMap { block -> [String] in
            guard case let .command(steps) = block.content else { return [] }
            return steps.map(\.displayCommand)
        }
    }

    private func runnableArguments(in issue: DoctorIssue) -> [[String]] {
        issue.blocks.compactMap { $0.runnableStep?.arguments }
    }

    private func dataItems(in issue: DoctorIssue) -> [String] {
        issue.blocks.flatMap { block -> [String] in
            guard case let .data(items) = block.content else { return [] }
            return items
        }
    }
}
