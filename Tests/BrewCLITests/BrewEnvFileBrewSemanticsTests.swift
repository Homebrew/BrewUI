@testable import BrewCLI
import BrewCore
import Foundation
import Testing

/// Defence-in-depth fixtures pinned to what `brew` master actually does with each line.
///
/// `brew` loads `brew.env` with:
///
/// ```bash
/// while read -r line; do
///   [[ "$line" =~ ^(HOMEBREW_|SUDO_ASKPASS=|(all|no|ftp|https?)_proxy=) ]] || continue
///   export "${line?}"
/// done
/// ```
///
/// So the value `brew` sees is the literal substring after the first `=`, *including* any quotes —
/// `read -r` doesn't strip them, and `export "${line?}"` doesn't shell-evaluate. These assertions
/// frame each case as "the value `brew` would see", not as "what our parser emits internally" — they
/// catch parser/writer drift even when the two stay internally consistent.
struct BrewEnvFileBrewSemanticsTests {
    @Test func `unquoted value: brew sees the value verbatim`() throws {
        let parsed = BrewEnvFileParser.parse("HOMEBREW_FOO=bar\n")
        #expect(parsed.value(forKey: "HOMEBREW_FOO") == "bar")

        let edited = BrewEnvFile().setting("HOMEBREW_FOO", value: "bar")
        #expect(try BrewEnvFileWriter.render(edited) == "HOMEBREW_FOO=bar\n")
    }

    @Test func `unquoted value with spaces: brew sees the spaces verbatim`() throws {
        let parsed = BrewEnvFileParser.parse("HOMEBREW_FOO=bar baz\n")
        #expect(parsed.value(forKey: "HOMEBREW_FOO") == "bar baz")

        let edited = BrewEnvFile().setting("HOMEBREW_FOO", value: "bar baz")
        #expect(try BrewEnvFileWriter.render(edited) == "HOMEBREW_FOO=bar baz\n")
    }

    @Test func `double-quoted value: brew sees the literal quotes`() throws {
        // brew exports `HOMEBREW_FOO="bar baz"` literally, so the value brew sees is `"bar baz"`
        // *including* the quote characters.
        let source = #"HOMEBREW_FOO="bar baz"\#n"#
        let parsed = BrewEnvFileParser.parse(source)
        #expect(parsed.value(forKey: "HOMEBREW_FOO") == #""bar baz""#)

        // Round-trip via raw — the writer preserves the on-disk form so we don't churn the user's
        // intent into something brew interprets differently.
        #expect(try BrewEnvFileWriter.render(parsed) == source)
    }

    @Test func `single-quoted value: brew sees the literal quotes`() throws {
        let source = "HOMEBREW_FOO='x'\n"
        let parsed = BrewEnvFileParser.parse(source)
        #expect(parsed.value(forKey: "HOMEBREW_FOO") == "'x'")
        #expect(try BrewEnvFileWriter.render(parsed) == source)
    }

    @Test func `export prefix: brew skips the line - we mark it inert`() throws {
        let source = "export HOMEBREW_FOO=1\n"
        let parsed = BrewEnvFileParser.parse(source)
        #expect(parsed.value(forKey: "HOMEBREW_FOO") == nil)
        #expect(parsed.lines == [.inert(rawText: "export HOMEBREW_FOO=1", reason: .hasExportPrefix)])
        #expect(try BrewEnvFileWriter.render(parsed) == source)
    }

    @Test func `non-HOMEBREW key: brew skips the line - we mark it inert`() throws {
        let source = "FOO=bar\n"
        let parsed = BrewEnvFileParser.parse(source)
        #expect(parsed.value(forKey: "FOO") == nil)
        #expect(parsed.lines == [.inert(rawText: "FOO=bar", reason: .nonHomebrewKey)])
        #expect(try BrewEnvFileWriter.render(parsed) == source)
    }

    @Test func `empty value: brew sees the empty string - written as bare KEY equals`() throws {
        // `KEY=""` would have brew read the literal value `""` (two characters). The honest empty is
        // `KEY=` with nothing after the equals.
        let edited = BrewEnvFile().setting("HOMEBREW_FOO", value: "")
        let rendered = try BrewEnvFileWriter.render(edited)
        #expect(rendered == "HOMEBREW_FOO=\n")

        let reparsed = BrewEnvFileParser.parse(rendered)
        #expect(reparsed.value(forKey: "HOMEBREW_FOO") == "")
    }

    @Test func `URL value with no quoting: brew sees the URL verbatim`() throws {
        // The cited HOMEBREW_BOTTLE_DOMAIN case from the addendum.
        let source = "HOMEBREW_BOTTLE_DOMAIN=https://example.com/bottles\n"
        let parsed = BrewEnvFileParser.parse(source)
        #expect(parsed.value(forKey: "HOMEBREW_BOTTLE_DOMAIN") == "https://example.com/bottles")
        #expect(try BrewEnvFileWriter.render(parsed) == source)
    }

    @Test func `leading whitespace: brew skips the line - we mark it inert`() throws {
        // brew's filter is `^`-anchored, so `   HOMEBREW_FOO=1` never matches and never reaches the
        // `export "${line?}"` step. Our parser must treat it as inert, not as a live entry.
        let source = "   HOMEBREW_FOO=1\n"
        let parsed = BrewEnvFileParser.parse(source)
        #expect(parsed.value(forKey: "HOMEBREW_FOO") == nil)
        #expect(parsed.lines == [.inert(rawText: "   HOMEBREW_FOO=1", reason: .leadingWhitespace)])
        #expect(try BrewEnvFileWriter.render(parsed) == source)
    }
}
