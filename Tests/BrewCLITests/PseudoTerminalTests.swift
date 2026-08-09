//
//  PseudoTerminalTests.swift
//  BrewTests
//

@testable import BrewCLI
import Foundation
import Testing

struct PseudoTerminalTests {
    @Test func `child spawned on the replica sees a terminal on stdout`() throws {
        let output = try runOnPseudoTerminal(script: "test -t 1 && printf 'tty' || printf 'not-tty'")

        #expect(output == "tty")
    }

    @Test func `child spawned on the replica sees a terminal on stderr`() throws {
        let output = try runOnPseudoTerminal(script: "test -t 2 && printf 'tty' || printf 'not-tty'")

        #expect(output == "tty")
    }

    @Test func `clearing OPOST leaves newlines untranslated`() throws {
        // With `OPOST`/`ONLCR` left on — the pty default — this would arrive as "one\r\ntwo\r\n".
        let output = try runOnPseudoTerminal(script: "printf 'one\\ntwo\\n'")

        #expect(output == "one\ntwo\n")
    }

    @Test func `carriage returns written by the child are preserved`() throws {
        // The distinction that makes progress redraws work: clearing `OPOST` suppresses the kernel's
        // own `\n` → `\r\n` rewrite without touching `\r` bytes the child emitted deliberately.
        let output = try runOnPseudoTerminal(script: "printf 'first\\rsecond\\n'")

        #expect(output == "first\rsecond\n")
    }

    @Test func `window size is reported to the child`() throws {
        // `stty` reads stdin, which stays on /dev/null by design (see `BrewCommandService`), so the query
        // is pointed at fd 1 — the pty. Tools that size their output do the same thing via `TIOCGWINSZ`
        // on stdout, so this is the path that actually matters.
        let output = try runOnPseudoTerminal(
            columns: 100,
            rows: 30,
            script: "stty size <&1",
        )

        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "30 100")
    }

    @Test func `read returns nil once the child and the local replica are gone`() throws {
        let terminal = try PseudoTerminal()
        let process = try startProcess(script: "printf 'done\\n'", terminal: terminal)
        terminal.closeReplica()

        var chunks: [Data] = []
        while let chunk = terminal.read() {
            chunks.append(chunk)
        }
        process.waitUntilExit()
        terminal.closePrimary()

        // The loop terminating at all is the assertion: a leaked replica descriptor would hang it forever.
        #expect(chunks.map { String(bytes: $0, encoding: .utf8) ?? "" }.joined() == "done\n")
    }

    @Test func `closing twice is harmless`() throws {
        let terminal = try PseudoTerminal()

        terminal.closeReplica()
        terminal.closeReplica()
        terminal.closePrimary()
        terminal.closePrimary()

        // Reaching here without a double-close fault (which would abort the process) is the assertion.
        #expect(Bool(true))
    }
}

private extension PseudoTerminalTests {
    /// Spawns `/bin/zsh -c script` with the terminal's replica as stdout+stderr, drains the primary to
    /// end-of-input, and returns the decoded output.
    func runOnPseudoTerminal(
        columns: UInt16 = PseudoTerminal.defaultColumns,
        rows: UInt16 = PseudoTerminal.defaultRows,
        script: String,
    ) throws -> String {
        let terminal = try PseudoTerminal(columns: columns, rows: rows)
        let process = try startProcess(script: script, terminal: terminal)
        terminal.closeReplica()

        var data = Data()
        while let chunk = terminal.read() {
            data.append(chunk)
        }
        process.waitUntilExit()
        terminal.closePrimary()

        return String(bytes: data, encoding: .utf8) ?? ""
    }

    /// Uses `Foundation.Process` deliberately: this exercises ``PseudoTerminal`` on its own, independent
    /// of how ``BrewCommandService`` spawns.
    func startProcess(script: String, terminal: PseudoTerminal) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", script]
        let replica = FileHandle(fileDescriptor: terminal.replicaDescriptor.rawValue, closeOnDealloc: false)
        process.standardOutput = replica
        process.standardError = replica
        process.standardInput = FileHandle.nullDevice
        try process.run()
        return process
    }
}
