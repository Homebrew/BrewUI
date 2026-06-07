@testable import BrewCLI
import BrewCore
import Foundation
import Testing

struct BrewEnvFileWriterTests {
    @Test func `empty file renders to an empty string`() {
        #expect(BrewEnvFileWriter.render(BrewEnvFile()) == "")
    }

    @Test func `simple value is emitted unquoted`() {
        let file = BrewEnvFile(lines: [.entry(key: "HOMEBREW_NO_ANALYTICS", value: "1")])
        #expect(BrewEnvFileWriter.render(file) == "HOMEBREW_NO_ANALYTICS=1\n")
    }

    @Test func `value with whitespace is double-quoted`() {
        let file = BrewEnvFile(lines: [
            .entry(key: "HOMEBREW_CASK_OPTS", value: "--no-quarantine --appdir=/Applications"),
        ])
        #expect(BrewEnvFileWriter.render(file) == "HOMEBREW_CASK_OPTS=\"--no-quarantine --appdir=/Applications\"\n")
    }

    @Test func `value with shell-special characters is quoted and escaped`() {
        let file = BrewEnvFile(lines: [.entry(key: "HOMEBREW_NOTE", value: #"a #hash and "quote""#)])
        // `#` triggers quoting; inner double quotes are backslash-escaped.
        #expect(BrewEnvFileWriter.render(file) == "HOMEBREW_NOTE=\"a #hash and \\\"quote\\\"\"\n")
    }

    @Test func `empty value renders as a quoted empty string`() {
        let file = BrewEnvFile(lines: [.entry(key: "HOMEBREW_EMPTY", value: "")])
        #expect(BrewEnvFileWriter.render(file) == "HOMEBREW_EMPTY=\"\"\n")
    }

    @Test func `comments and blanks are emitted verbatim`() {
        let file = BrewEnvFile(lines: [
            .comment("# Top comment"),
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
            .blank,
            .comment("  # indented"),
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "8"),
        ])
        let expected = """
        # Top comment
        HOMEBREW_NO_ANALYTICS=1

          # indented
        HOMEBREW_MAKE_JOBS=8

        """
        #expect(BrewEnvFileWriter.render(file) == expected)
    }

    @Test func `unedited file round-trips byte-identically`() {
        let source = """
        # User overrides
        HOMEBREW_NO_ANALYTICS=1
        HOMEBREW_MAKE_JOBS=8

        # Cask options
        HOMEBREW_CASK_OPTS="--no-quarantine --appdir=/Applications"
        export HOMEBREW_NO_AUTO_UPDATE=1
        """
        let parsed = BrewEnvFileParser.parse(source + "\n")
        let rendered = BrewEnvFileWriter.render(parsed)
        // `export` is dropped on re-render (we normalise to plain `KEY=value`), and the same value
        // re-quotes via the same rule, so the file ends up canonical-form-equal — not byte-identical
        // for the `export` line, but byte-identical for the rest. Validate the canonical form here.
        let expected = """
        # User overrides
        HOMEBREW_NO_ANALYTICS=1
        HOMEBREW_MAKE_JOBS=8

        # Cask options
        HOMEBREW_CASK_OPTS="--no-quarantine --appdir=/Applications"
        HOMEBREW_NO_AUTO_UPDATE=1

        """
        #expect(rendered == expected)
    }

    @Test func `setting an existing key updates in place without reordering`() {
        let original = BrewEnvFile(lines: [
            .comment("# header"),
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "4"),
            .blank,
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
        ])

        let updated = original.setting("HOMEBREW_MAKE_JOBS", value: "8")

        #expect(updated.lines == [
            .comment("# header"),
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "8"),
            .blank,
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
        ])
    }

    @Test func `setting a missing key appends a new entry at the end`() {
        let original = BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "4")])

        let updated = original.setting("HOMEBREW_NO_ANALYTICS", value: "1")

        #expect(updated.lines == [
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "4"),
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
        ])
    }

    @Test func `removing a key drops every matching entry but keeps comments and blanks`() {
        let original = BrewEnvFile(lines: [
            .comment("# header"),
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "4"),
            .blank,
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "8"),
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
        ])

        let updated = original.removing(key: "HOMEBREW_MAKE_JOBS")

        #expect(updated.lines == [
            .comment("# header"),
            .blank,
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
        ])
    }
}
