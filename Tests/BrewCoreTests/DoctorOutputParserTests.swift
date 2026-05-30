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

    // MARK: - Anchored Affected (the original-bug fix)

    @Test func `unlinked-kegs cue collects indented items into Affected`() throws {
        let output = """
        Warning: You have unlinked kegs in your Cellar.
        Leaving kegs unlinked can lead to build-trouble. Run `brew link` on these:
          openssl@3
          readline
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.affectedItems == ["openssl@3", "readline"])
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
        #expect(issue.affectedItems == ["/opt/homebrew", "/opt/homebrew/bin"])
    }

    @Test func `value lines without a recognized cue stay out of Affected`() throws {
        // `which resolves to: /path` is a key/value line. Without a data-intro cue, it must not be
        // collected — that was the original bug.
        let output = """
        Warning: Your Cellar is symlinked.
        which resolves to: /opt/homebrew/Cellar
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.affectedItems.isEmpty)
    }

    @Test func `tools-at-both-paths block stays as one data block (no command scatter)`() throws {
        // The original scatter bug: pip3/python3 look like commands per line, but the block's first
        // member (openssl) isn't, so the whole block is data.
        let output = """
        Warning: The following tools exist at both paths:
          openssl
          pip3
          python3
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.affectedItems == ["openssl", "pip3", "python3"])
        #expect(issue.fixSequences.isEmpty)
    }

    @Test func `broken-symlinks block classifies as data via the first member, no intro cue needed`() throws {
        // `Remove them with `brew cleanup`:` ends with a backtick before the colon — no enumerated
        // cue could match it. The first-member rule handles it because the first item is a path.
        let output = """
        Warning: Broken symlinks were found. Remove them with `brew cleanup`:
          /opt/homebrew/bin/foo
          /opt/homebrew/bin/bar
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.affectedItems == ["/opt/homebrew/bin/foo", "/opt/homebrew/bin/bar"])
        #expect(issue.fixSequences.isEmpty)
    }

    @Test func `stray command with no colon intro is still captured`() throws {
        // `check_git_status` / `check_multiple_cellars`: the command sits under period-ending prose,
        // not a colon intro. The .prose fallback catches it via the allowlist.
        let output = """
        Warning: Uncommitted git changes.
        Your homebrew git repo has uncommitted changes.
          git -C /opt/homebrew stash
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        let sequence = try #require(issue.fixSequences.first)
        #expect(sequence.steps.map(\.displayCommand) == ["git -C /opt/homebrew stash"])
    }

    @Test func `echo PATH one-liner classifies as a command block`() throws {
        // The shell-profile fix from check_user_path_* — first member is `echo …`, in the allowlist.
        let output = """
        Warning: Homebrew's bin was not found in your PATH.
        Consider setting your PATH for example like so:
          echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        let sequence = try #require(issue.fixSequences.first)
        #expect(sequence.steps.first?.displayCommand.hasPrefix("echo ") == true)
    }

    @Test func `dataNounCue forces data even when the first item looks like a command`() throws {
        // Deprecated formulae list could contain a name that reads as a command (e.g. a formula
        // literally named `git`). The intro contains "formulae" → data noun cue → data block.
        let output = """
        Warning: Some installed formulae are deprecated or disabled.
        You should find replacements for the following formulae:
          git
          python
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.affectedItems == ["git", "python"])
        #expect(issue.fixSequences.isEmpty)
    }

    @Test func `value lines inside a data block fall through to prose, not Affected`() throws {
        // `core.autocrlf = true` shouldn't end up as an Affected item even though it lives under a
        // colon intro that classifies as data.
        let output = """
        Warning: Suspicious git newline settings.
        The detected git configuration values are:
          core.autocrlf = true
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(!issue.affectedItems.contains("core.autocrlf = true"))
    }

    // MARK: - Fix sequences

    @Test func `indented brew command is captured as a runnable fix sequence`() throws {
        let output = """
        Warning: Out of date.
        Update guidance:
          brew upgrade git
        """
        let sequence = try #require(DoctorOutputParser.parse(output).issues.first?.fixSequences.first)
        #expect(sequence.steps.count == 1)
        #expect(sequence.steps[0].displayCommand == "brew upgrade git")
        #expect(sequence.steps[0].arguments == ["upgrade", "git"])
        #expect(sequence.steps[0].needsAdmin == false)
        #expect(sequence.isRunnable == true)
    }

    @Test func `sudo step is flagged as admin and not runnable`() throws {
        let output = """
        Warning: Bad perms.
        Take ownership:
          sudo chown -R me /opt/homebrew
        """
        let sequence = try #require(DoctorOutputParser.parse(output).issues.first?.fixSequences.first)
        #expect(sequence.steps[0].needsAdmin == true)
        #expect(sequence.steps[0].arguments == nil)
        #expect(sequence.isRunnable == false)
    }

    @Test func `consecutive command lines are grouped into one sequence; a blank line starts a new one`() {
        let output = """
        Warning: Multi-step.
        First:
          mkdir -p /opt/homebrew
          chown -R me /opt/homebrew

        Then:
          brew tap homebrew/core
        """
        let report = DoctorOutputParser.parse(output)
        let sequences = report.issues.first?.fixSequences ?? []
        #expect(sequences.count == 2)
        #expect(sequences[0].steps.map(\.displayCommand) == ["mkdir -p /opt/homebrew", "chown -R me /opt/homebrew"])
        #expect(sequences[1].steps.map(\.displayCommand) == ["brew tap homebrew/core"])
    }

    // MARK: - Inline chips (brew-only, with arguments)

    @Test func `backticked brew reference becomes a chip but does not promote into fixSequences`() throws {
        let output = """
        Warning: Stale caches.
        Please run `brew cleanup` to remove them.
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.inlineChips.map(\.displayCommand) == ["brew cleanup"])
        #expect(issue.inlineChips.first?.arguments == ["cleanup"])
        #expect(issue.fixSequences.isEmpty)
    }

    @Test func `non-executable backticked spans are not chips`() throws {
        let output = """
        Warning: Config touched.
        Edit your `.gitconfig` directly.
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        #expect(issue.inlineChips.isEmpty)
    }

    // MARK: - Links

    @Test func `developer.apple.com is an action link; docs.brew.sh is reference`() throws {
        let output = """
        Warning: Install CLT.
        Manual download: https://developer.apple.com/download/
        Or read the support tiers: https://docs.brew.sh/Support-Tiers
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        let roles = Dictionary(uniqueKeysWithValues: issue.links.map { ($0.url.host ?? "", $0.role) })
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
}
