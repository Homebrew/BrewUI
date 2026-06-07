@testable import BrewCLI
import BrewCore
import Foundation
import Testing

struct BrewEnvFileWriterTests {
    @Test func `empty file renders to an empty string`() throws {
        #expect(try BrewEnvFileWriter.render(BrewEnvFile()) == "")
    }

    @Test func `new entry renders as unquoted KEY equals value`() throws {
        let file = BrewEnvFile(lines: [.entry(key: "HOMEBREW_NO_ANALYTICS", value: "1")])
        #expect(try BrewEnvFileWriter.render(file) == "HOMEBREW_NO_ANALYTICS=1\n")
    }

    @Test func `value with whitespace is emitted raw - no quoting`() throws {
        // brew runs `export "${line?}"` with no shell evaluation, so any quoting here would become
        // part of the value brew sees. Emit the value literally.
        let file = BrewEnvFile(lines: [
            .entry(key: "HOMEBREW_CASK_OPTS", value: "--no-quarantine --appdir=/Applications"),
        ])
        #expect(try BrewEnvFileWriter.render(file) == "HOMEBREW_CASK_OPTS=--no-quarantine --appdir=/Applications\n")
    }

    @Test func `value with shell-special characters is emitted raw`() throws {
        // brew doesn't shell-evaluate the value, so `#` and embedded quotes pass through unchanged.
        let file = BrewEnvFile(lines: [.entry(key: "HOMEBREW_NOTE", value: #"a #hash and "quote""#)])
        #expect(try BrewEnvFileWriter.render(file) == #"HOMEBREW_NOTE=a #hash and "quote"\#n"#)
    }

    @Test func `empty value renders as bare KEY equals`() throws {
        // `KEY=""` would have brew read the literal value `""` (two characters). Emit the honest empty.
        let file = BrewEnvFile(lines: [.entry(key: "HOMEBREW_EMPTY", value: "")])
        #expect(try BrewEnvFileWriter.render(file) == "HOMEBREW_EMPTY=\n")
    }

    @Test func `newline in entry value throws rather than corrupting the file`() {
        let file = BrewEnvFile(lines: [.entry(key: "HOMEBREW_NOTE", value: "first\nsecond")])
        #expect(throws: BrewEnvFileWriterError.newlineInValue(key: "HOMEBREW_NOTE")) {
            try BrewEnvFileWriter.render(file)
        }
    }

    @Test func `comments and blanks are emitted verbatim`() throws {
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
        #expect(try BrewEnvFileWriter.render(file) == expected)
    }

    @Test func `parsed entry with raw round-trips byte-identically`() throws {
        // The parser stashes the on-disk substring on each `.entry`; the writer re-emits it. So a
        // file with quirky whitespace, quoting, or inert lines round-trips verbatim even though the
        // writer's canonical form for a fresh entry differs.
        let source = """
        # User overrides
        HOMEBREW_NO_ANALYTICS=1
        HOMEBREW_MAKE_JOBS=8

        # Cask options
        HOMEBREW_CASK_OPTS="--no-quarantine --appdir=/Applications"
        export HOMEBREW_NO_AUTO_UPDATE=1
        FOO=bar

        """
        let parsed = BrewEnvFileParser.parse(source)
        #expect(try BrewEnvFileWriter.render(parsed) == source)
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

    @Test func `setting an entry with the same value preserves its raw substring`() {
        // Same value → no re-render. Distinct from "edit": we don't want a no-op save to churn the
        // line into canonical form when the user hand-formatted it.
        let original = BrewEnvFile(lines: [
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "8", raw: "  HOMEBREW_MAKE_JOBS=8"),
        ])

        let updated = original.setting("HOMEBREW_MAKE_JOBS", value: "8")

        #expect(updated.lines == [
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "8", raw: "  HOMEBREW_MAKE_JOBS=8"),
        ])
    }

    @Test func `setting an entry to a new value clears its raw substring`() {
        let original = BrewEnvFile(lines: [
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "4", raw: #"HOMEBREW_MAKE_JOBS="4""#),
        ])

        let updated = original.setting("HOMEBREW_MAKE_JOBS", value: "8")

        #expect(updated.lines == [
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "8", raw: nil),
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

    @Test func `removing a key drops every matching entry but keeps comments, blanks, and inert lines`() {
        let original = BrewEnvFile(lines: [
            .comment("# header"),
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "4"),
            .blank,
            .inert(rawText: "export HOMEBREW_MAKE_JOBS=99", reason: .hasExportPrefix),
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "8"),
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
        ])

        let updated = original.removing(key: "HOMEBREW_MAKE_JOBS")

        #expect(updated.lines == [
            .comment("# header"),
            .blank,
            .inert(rawText: "export HOMEBREW_MAKE_JOBS=99", reason: .hasExportPrefix),
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
        ])
    }

    @Test func `inert lines round-trip verbatim via the writer`() throws {
        // .inert exists precisely so a save doesn't drop content brew can't load. Confirm the writer
        // emits the stored rawText for both inert reasons.
        let file = BrewEnvFile(lines: [
            .inert(rawText: "export HOMEBREW_NO_AUTO_UPDATE=1", reason: .hasExportPrefix),
            .inert(rawText: "FOO=bar", reason: .nonHomebrewKey),
        ])
        #expect(try BrewEnvFileWriter.render(file) == "export HOMEBREW_NO_AUTO_UPDATE=1\nFOO=bar\n")
    }
}
