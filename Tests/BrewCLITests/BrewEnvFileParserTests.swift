@testable import BrewCLI
import BrewCore
import Foundation
import Testing

struct BrewEnvFileParserTests {
    @Test func `empty input yields no lines`() {
        #expect(BrewEnvFileParser.parse("").lines.isEmpty)
    }

    @Test func `single trailing newline does not produce a phantom blank line`() {
        let parsed = BrewEnvFileParser.parse("HOMEBREW_NO_ANALYTICS=1\n")
        #expect(parsed.lines == [
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1", raw: "HOMEBREW_NO_ANALYTICS=1"),
        ])
    }

    @Test func `extra trailing newlines are preserved as blank lines`() {
        let parsed = BrewEnvFileParser.parse("HOMEBREW_NO_ANALYTICS=1\n\n\n")
        #expect(parsed.lines == [
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1", raw: "HOMEBREW_NO_ANALYTICS=1"),
            .blank,
            .blank,
        ])
    }

    @Test func `comments and blank lines are preserved verbatim`() {
        let source = """
        # Top comment
        HOMEBREW_NO_ANALYTICS=1

          # indented comment
        HOMEBREW_MAKE_JOBS=8
        """
        let parsed = BrewEnvFileParser.parse(source)
        #expect(parsed.lines == [
            .comment("# Top comment"),
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1", raw: "HOMEBREW_NO_ANALYTICS=1"),
            .blank,
            .comment("  # indented comment"),
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "8", raw: "HOMEBREW_MAKE_JOBS=8"),
        ])
    }

    @Test func `export prefix is surfaced as inert - brew won't load it`() {
        // brew's regex requires the line to start with `HOMEBREW_` etc. — `export …` is rejected.
        // Preserved so the UI can flag it instead of laundering it into an active setting.
        let parsed = BrewEnvFileParser.parse("export HOMEBREW_NO_AUTO_UPDATE=1")
        #expect(parsed.lines == [
            .inert(rawText: "export HOMEBREW_NO_AUTO_UPDATE=1", reason: .hasExportPrefix),
        ])
        #expect(parsed.value(forKey: "HOMEBREW_NO_AUTO_UPDATE") == nil)
    }

    @Test func `non-HOMEBREW key is surfaced as inert`() {
        // brew only loads HOMEBREW_*, SUDO_ASKPASS, and the lowercase proxy vars. Anything else
        // sits on disk but never reaches `brew`.
        let parsed = BrewEnvFileParser.parse("FOO=bar")
        #expect(parsed.lines == [.inert(rawText: "FOO=bar", reason: .nonHomebrewKey)])
        #expect(parsed.value(forKey: "FOO") == nil)
    }

    @Test func `SUDO_ASKPASS is loaded by brew - treated as an entry`() {
        let parsed = BrewEnvFileParser.parse("SUDO_ASKPASS=/usr/bin/ssh-askpass")
        #expect(parsed.lines == [
            .entry(key: "SUDO_ASKPASS", value: "/usr/bin/ssh-askpass", raw: "SUDO_ASKPASS=/usr/bin/ssh-askpass"),
        ])
    }

    @Test func `proxy keys are loaded by brew - treated as entries`() {
        let source = """
        http_proxy=http://proxy:8080
        https_proxy=http://proxy:8080
        ftp_proxy=http://proxy:8080
        no_proxy=localhost
        all_proxy=socks5://proxy:1080
        """
        let parsed = BrewEnvFileParser.parse(source)
        #expect(parsed.entries.map(\.key) == ["http_proxy", "https_proxy", "ftp_proxy", "no_proxy", "all_proxy"])
    }

    @Test func `double-quoted value is preserved literally - quotes become part of the value`() {
        // brew runs `export "${line?}"`, so the quote characters become part of the exported value.
        // Surface the value literally rather than silently stripping the quotes.
        let source = #"HOMEBREW_CASK_OPTS="--no-quarantine --appdir=/Applications""#
        let parsed = BrewEnvFileParser.parse(source)
        #expect(parsed.lines == [
            .entry(
                key: "HOMEBREW_CASK_OPTS",
                value: #""--no-quarantine --appdir=/Applications""#,
                raw: source,
            ),
        ])
    }

    @Test func `single-quoted value is preserved literally`() {
        let parsed = BrewEnvFileParser.parse("HOMEBREW_CASK_OPTS='value with spaces'")
        #expect(parsed.lines == [
            .entry(
                key: "HOMEBREW_CASK_OPTS",
                value: "'value with spaces'",
                raw: "HOMEBREW_CASK_OPTS='value with spaces'",
            ),
        ])
    }

    @Test func `values containing equals signs keep everything after the first equals`() {
        let parsed = BrewEnvFileParser.parse("HOMEBREW_GITHUB_API_TOKEN=ghp_abc=def==trailing")
        #expect(parsed.lines == [
            .entry(
                key: "HOMEBREW_GITHUB_API_TOKEN",
                value: "ghp_abc=def==trailing",
                raw: "HOMEBREW_GITHUB_API_TOKEN=ghp_abc=def==trailing",
            ),
        ])
    }

    @Test func `lines without an equals are kept as comments to round-trip`() {
        let parsed = BrewEnvFileParser.parse("not a valid entry line")
        #expect(parsed.lines == [.comment("not a valid entry line")])
    }

    @Test func `lines whose key is not a shell identifier are kept as comments`() {
        // `1FOO=bar` is invalid shell — start with a digit. Preserved verbatim so save doesn't drop it.
        let parsed = BrewEnvFileParser.parse("1FOO=bar")
        #expect(parsed.lines == [.comment("1FOO=bar")])
    }

    @Test func `last-wins helpers see the most recent entry for a key`() {
        let parsed = BrewEnvFileParser.parse("HOMEBREW_MAKE_JOBS=4\nHOMEBREW_MAKE_JOBS=8")
        #expect(parsed.value(forKey: "HOMEBREW_MAKE_JOBS") == "8")
        #expect(parsed.entries.map(\.key) == ["HOMEBREW_MAKE_JOBS"])
        #expect(parsed.entries.first?.value == "8")
    }

    @Test func `leading whitespace on a HOMEBREW key surfaces as inert`() {
        // brew's filter is `^`-anchored; a leading space or tab means the line never reaches `export`.
        // Treat it as inert so the UI can't claim a value is live when brew won't see it.
        let parsed = BrewEnvFileParser.parse(" HOMEBREW_NO_ANALYTICS=1\n\tHOMEBREW_MAKE_JOBS=8")
        #expect(parsed.lines == [
            .inert(rawText: " HOMEBREW_NO_ANALYTICS=1", reason: .leadingWhitespace),
            .inert(rawText: "\tHOMEBREW_MAKE_JOBS=8", reason: .leadingWhitespace),
        ])
        #expect(parsed.value(forKey: "HOMEBREW_NO_ANALYTICS") == nil)
        #expect(parsed.value(forKey: "HOMEBREW_MAKE_JOBS") == nil)
    }
}
