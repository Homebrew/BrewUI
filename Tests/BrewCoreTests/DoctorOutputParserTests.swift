//
//  DoctorOutputParserTests.swift
//  BrewTests
//

import BrewCore
import Foundation
import Testing

private extension DoctorIssue {
    /// All `.data` block items across the issue.
    var allDataItems: [String] {
        blocks.flatMap { block -> [String] in
            guard case let .data(items) = block.content else {
                return []
            }
            return items
        }
    }

    /// All `.command` blocks (in document order).
    var commandBlocks: [DoctorBlock] {
        blocks.filter { $0.type == .command }
    }

    /// All `.link` block URLs across the issue, host + role.
    var allLinks: [(host: String, role: DoctorLinkRole)] {
        blocks.flatMap { block -> [DoctorLink] in
            guard case let .link(links) = block.content else {
                return []
            }
            return links
        }.map { ($0.url.host ?? "", $0.role) }
    }
}

private extension DoctorBlock {
    var commandSteps: [DoctorFixStep] {
        guard case let .command(steps) = content else {
            return []
        }
        return steps
    }
}

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
    }

    // MARK: - Severity

    @Test func `unflagged warning is caution`() {
        let issue = DoctorOutputParser.parse("Warning: Generic.\nA detail.").issues.first
        #expect(issue?.severity == .caution)
    }

    @Test func `tier callouts are mapped to severity`() {
        let tier1 = DoctorOutputParser.parse("Warning: Tier 1 issue.\nThis is a Tier 1 configuration:").issues.first
        let tier2 = DoctorOutputParser.parse("Warning: Tier 2 issue.\nThis is a Tier 2 configuration:").issues.first
        let tier3 = DoctorOutputParser.parse("Warning: Tier 3 issue.\nThis is a Tier 3 configuration:").issues.first
        #expect(tier1?.severity == .info)
        #expect(tier2?.severity == .caution)
        #expect(tier3?.severity == .danger)
    }

    @Test func `unsupported configuration trumps any tier`() {
        let output = """
        Warning: Unsupported macOS.
        Unsupported configuration: please upgrade.
        """
        #expect(DoctorOutputParser.parse(output).issues.first?.severity == .unsupported)
    }

    // MARK: - Anchored data blocks (the original-bug fix)

    @Test func `unlinked-kegs cue collects indented items into a data block`() throws {
        let output = """
        Warning: You have unlinked kegs in your Cellar.
        Leaving kegs unlinked can lead to build-trouble. Run `brew link` on these:
          openssl@3
          readline
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.allDataItems == ["openssl@3", "readline"])
    }

    @Test func `not-writable-directories cue collects un-indented paths`() throws {
        let output = """
        Warning: The following directories are not writable by your user:
        /opt/homebrew
        /opt/homebrew/bin

        You should change the ownership of these directories to your user.
          sudo chown -R me /opt/homebrew /opt/homebrew/bin
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.allDataItems == ["/opt/homebrew", "/opt/homebrew/bin"])
    }

    @Test func `value lines without a recognized cue produce no data block`() throws {
        let output = """
        Warning: Your Cellar is symlinked.
        which resolves to: /opt/homebrew/Cellar
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.allDataItems.isEmpty)
    }

    @Test func `tools-at-both-paths block stays as one data block (no command scatter)`() throws {
        let output = """
        Warning: The following tools exist at both paths:
          openssl
          pip3
          python3
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.allDataItems == ["openssl", "pip3", "python3"])
        #expect(issue.commandBlocks.isEmpty)
    }

    @Test func `broken-symlinks block classifies as data via the first member, no intro cue needed`() throws {
        let output = """
        Warning: Broken symlinks were found. Remove them with `brew cleanup`:
          /opt/homebrew/bin/foo
          /opt/homebrew/bin/bar
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.allDataItems == ["/opt/homebrew/bin/foo", "/opt/homebrew/bin/bar"])
        #expect(issue.commandBlocks.isEmpty)
    }

    @Test func `stray command with no colon intro is still captured`() throws {
        let output = """
        Warning: Uncommitted git changes.
        Your homebrew git repo has uncommitted changes.
          git -C /opt/homebrew stash
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        let block = try #require(issue.commandBlocks.first)
        #expect(block.commandSteps.map(\.displayCommand) == ["git -C /opt/homebrew stash"])
    }

    @Test func `echo PATH one-liner classifies as a command block`() throws {
        let output = """
        Warning: Homebrew's bin was not found in your PATH.
        Consider setting your PATH for example like so:
          echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        let block = try #require(issue.commandBlocks.first)
        #expect(block.commandSteps.first?.displayCommand.hasPrefix("echo ") == true)
    }

    @Test func `dataNounCue forces data even when the first item looks like a command`() throws {
        let output = """
        Warning: Some installed formulae are deprecated or disabled.
        You should find replacements for the following formulae:
          git
          python
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.allDataItems == ["git", "python"])
        #expect(issue.commandBlocks.isEmpty)
    }

    @Test func `value lines inside a data block are skipped, not collected`() throws {
        let output = """
        Warning: Suspicious git newline settings.
        The detected git configuration values are:
          core.autocrlf = true
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(!issue.allDataItems.contains("core.autocrlf = true"))
    }

    // MARK: - Captions stay on their block

    @Test func `colon intro is kept as the block's caption, not pushed into prose`() throws {
        let output = """
        Warning: Out of date.
        Update guidance:
          brew upgrade git
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        let block = try #require(issue.commandBlocks.first)
        #expect(block.caption == "Update guidance:")
        // The intro shouldn't appear in any prose block either.
        let proseLines = issue.blocks.compactMap { block -> [String]? in
            guard case let .prose(lines) = block.content else {
                return nil
            }
            return lines
        }.flatMap(\.self)
        #expect(!proseLines.contains("Update guidance:"))
    }

    // MARK: - Command blocks

    @Test func `indented brew command is captured as a runnable command block`() throws {
        let output = """
        Warning: Out of date.
        Update guidance:
          brew upgrade git
        """
        let block = try #require(DoctorOutputParser.parse(output).issues.first?.commandBlocks.first)
        let step = try #require(block.commandSteps.first)
        #expect(block.commandSteps.count == 1)
        #expect(step.displayCommand == "brew upgrade git")
        #expect(step.arguments == ["upgrade", "git"])
        #expect(step.needsAdmin == false)
        #expect(block.isRunnable == true)
    }

    @Test func `sudo step is flagged as admin and not runnable`() throws {
        let output = """
        Warning: Bad perms.
        Take ownership:
          sudo chown -R me /opt/homebrew
        """
        let block = try #require(DoctorOutputParser.parse(output).issues.first?.commandBlocks.first)
        #expect(block.commandSteps[0].needsAdmin == true)
        #expect(block.commandSteps[0].arguments == nil)
        #expect(block.isRunnable == false)
    }

    @Test func `consecutive command lines stay in one block; blank line opens a new one`() {
        let output = """
        Warning: Multi-step.
        First:
          mkdir -p /opt/homebrew
          chown -R me /opt/homebrew

        Then:
          brew tap homebrew/core
        """
        let blocks = DoctorOutputParser.parse(output).issues.first?.commandBlocks ?? []
        #expect(blocks.count == 2)
        #expect(blocks[0].commandSteps.map(\.displayCommand) == ["mkdir -p /opt/homebrew", "chown -R me /opt/homebrew"])
        #expect(blocks[1].commandSteps.map(\.displayCommand) == ["brew tap homebrew/core"])
        #expect(blocks[0].caption == "First:")
        #expect(blocks[1].caption == "Then:")
    }

    // MARK: - Inline chips (brew-only, with arguments)

    @Test func `backticked brew reference becomes a chip but does not promote into a command block`() throws {
        let output = """
        Warning: Stale caches.
        Please run `brew cleanup` to remove them.
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.inlineChips.map(\.displayCommand) == ["brew cleanup"])
        #expect(issue.inlineChips.first?.arguments == ["cleanup"])
        #expect(issue.commandBlocks.isEmpty)
    }

    @Test func `non-executable backticked spans are not chips`() throws {
        let output = """
        Warning: Config touched.
        Edit your `.gitconfig` directly.
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.inlineChips.isEmpty)
    }

    // MARK: - Link blocks

    @Test func `developer.apple.com link block is action; docs.brew.sh is reference`() throws {
        let output = """
        Warning: Install CLT.
        Manual download:
          https://developer.apple.com/download/

        Tier reference:
          https://docs.brew.sh/Support-Tiers
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        let roles = Dictionary(uniqueKeysWithValues: issue.allLinks.map { ($0.host, $0.role) })
        #expect(roles["developer.apple.com"] == .action)
        #expect(roles["docs.brew.sh"] == .reference)
    }

    // MARK: - Raw body fallback

    @Test func `raw body preserves the verbatim block beneath the title`() throws {
        let body = "Line one.\n  brew upgrade git\nLine three."
        let output = "Warning: Something.\n" + body
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.rawBody == body)
    }

    // MARK: - Multiple warnings

    @Test func `multiple warnings parse in order`() {
        let output = """
        Warning: First problem.
        Detail one.

        Warning: Second problem.
        Detail two.
        """
        let titles = DoctorOutputParser.parse(output).issues.map(\.title)
        #expect(titles == ["First problem.", "Second problem."])
    }

    // MARK: - Section classifier

    @Test func `xcode and CLT title routes to xcodeAndCLT section`() {
        let output = "Warning: Xcode is outdated.\nUpdate it from the App Store."
        #expect(DoctorOutputParser.parse(output).issues.first?.section == .xcodeAndCLT)
    }

    @Test func `your PATH title routes to environmentAndPath section`() {
        let output = "Warning: Homebrew's bin was not found in your PATH.\nFix your shell rc."
        #expect(DoctorOutputParser.parse(output).issues.first?.section == .environmentAndPath)
    }

    @Test func `cask in title routes to casks section`() {
        let output = "Warning: A cask is broken.\nDetails."
        #expect(DoctorOutputParser.parse(output).issues.first?.section == .casks)
    }

    @Test func `git origin keywords route to tapsAndGit section`() {
        let output = "Warning: Missing git origin remote.\nFix it."
        #expect(DoctorOutputParser.parse(output).issues.first?.section == .tapsAndGit)
    }

    @Test func `stray dylibs route to strayFiles section`() {
        let output = "Warning: Unbrewed dylibs were found.\nDetails."
        #expect(DoctorOutputParser.parse(output).issues.first?.section == .strayFiles)
    }

    @Test func `unlinked kegs falls through to default systemAndFormulae`() {
        let output = "Warning: You have unlinked kegs in your Cellar.\nDetails."
        #expect(DoctorOutputParser.parse(output).issues.first?.section == .systemAndFormulae)
    }
}
