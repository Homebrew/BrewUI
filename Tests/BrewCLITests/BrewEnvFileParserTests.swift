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
        #expect(parsed.lines == [.entry(key: "HOMEBREW_NO_ANALYTICS", value: "1")])
    }

    @Test func `extra trailing newlines are preserved as blank lines`() {
        // Trailing-blank preservation matters for the writer's round-trip guarantee.
        let parsed = BrewEnvFileParser.parse("HOMEBREW_NO_ANALYTICS=1\n\n\n")
        #expect(parsed.lines == [
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
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
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
            .blank,
            .comment("  # indented comment"),
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "8"),
        ])
    }

    @Test func `export prefix is stripped from entry lines`() {
        let parsed = BrewEnvFileParser.parse("export HOMEBREW_NO_AUTO_UPDATE=1")
        #expect(parsed.lines == [.entry(key: "HOMEBREW_NO_AUTO_UPDATE", value: "1")])
    }

    @Test func `double-quoted values are unwrapped`() {
        let parsed = BrewEnvFileParser.parse(#"HOMEBREW_CASK_OPTS="--no-quarantine --appdir=/Applications""#)
        #expect(parsed.lines == [
            .entry(key: "HOMEBREW_CASK_OPTS", value: "--no-quarantine --appdir=/Applications"),
        ])
    }

    @Test func `single-quoted values are unwrapped`() {
        let parsed = BrewEnvFileParser.parse("HOMEBREW_CASK_OPTS='value with spaces'")
        #expect(parsed.lines == [
            .entry(key: "HOMEBREW_CASK_OPTS", value: "value with spaces"),
        ])
    }

    @Test func `values containing equals signs keep everything after the first equals`() {
        let parsed = BrewEnvFileParser.parse("HOMEBREW_GITHUB_API_TOKEN=ghp_abc=def==trailing")
        #expect(parsed.lines == [
            .entry(key: "HOMEBREW_GITHUB_API_TOKEN", value: "ghp_abc=def==trailing"),
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
}
