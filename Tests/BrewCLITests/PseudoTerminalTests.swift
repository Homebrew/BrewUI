//
//  PseudoTerminalTests.swift
//  BrewTests
//

@testable import BrewCLI
import Foundation
import Testing

/// Serialized: the pty device pool is small (~36 concurrent, far below what `kern.tty.ptmx_max`
/// advertises), so running these in parallel exhausts it and fails with ENXIO.
@Suite(.serialized)
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
        let output = try runOnPseudoTerminal(script: "printf 'one\\ntwo\\n'")

        #expect(output == "one\ntwo\n")
    }

    @Test func `carriage returns written by the child are preserved`() throws {
        let output = try runOnPseudoTerminal(script: "printf 'first\\rsecond\\n'")

        #expect(output == "first\rsecond\n")
    }

    @Test func `window size is reported to the child`() throws {
        // `stty` reads stdin, which stays on /dev/null by design, so the query is pointed at fd 1.
        let output = try runOnPseudoTerminal(
            columns: 100,
            rows: 30,
            script: "stty size <&1",
        )

        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "30 100")
    }

    @Test func `read reports end of input once the child and the local replica are gone`() throws {
        let terminal = try PseudoTerminal()
        let process = try startProcess(script: "printf 'done\\n'", terminal: terminal)
        terminal.closeReplica()

        let output = drainToEndOfInput(terminal)
        process.waitUntilExit()
        terminal.closePrimary()

        // Terminating at all is the assertion: a leaked replica descriptor would hang this forever.
        #expect(output == "done\n")
    }

    @Test func `read times out rather than blocking while the terminal is idle`() throws {
        let terminal = try PseudoTerminal()
        // Nothing to read and no end-of-input either, so an unbounded read would park forever.
        defer {
            terminal.closeReplica()
            terminal.closePrimary()
        }

        let outcome = terminal.read(timeout: .milliseconds(50))

        #expect(outcome == .timedOut)
    }

    @Test func `read reports end of input when only the local replica is closed`() throws {
        let terminal = try PseudoTerminal()
        terminal.closeReplica()
        defer { terminal.closePrimary() }

        let outcome = terminal.read(timeout: .milliseconds(50))

        #expect(outcome == .endOfInput)
    }

    @Test func `closing twice is harmless`() throws {
        let terminal = try PseudoTerminal()

        terminal.closeReplica()
        terminal.closeReplica()
        terminal.closePrimary()
        terminal.closePrimary()

        // Reaching here without a double-close fault is the assertion.
        #expect(Bool(true))
    }
}

private extension PseudoTerminalTests {
    /// Runs `script` with the replica as stdout+stderr and drains the primary to end-of-input.
    func runOnPseudoTerminal(
        columns: UInt16 = PseudoTerminal.defaultColumns,
        rows: UInt16 = PseudoTerminal.defaultRows,
        script: String,
    ) throws -> String {
        let terminal = try PseudoTerminal(columns: columns, rows: rows)
        let process = try startProcess(script: script, terminal: terminal)
        terminal.closeReplica()

        let output = drainToEndOfInput(terminal)
        process.waitUntilExit()
        terminal.closePrimary()

        return output
    }

    /// Ignores idle timeouts; safe because every script under test terminates on its own.
    func drainToEndOfInput(_ terminal: PseudoTerminal) -> String {
        var data = Data()
        loop: while true {
            switch terminal.read() {
            case let .data(chunk):
                data.append(chunk)
            case .timedOut:
                continue
            case .endOfInput:
                break loop
            case let .failed(code):
                Issue.record("reading the terminal failed: \(PseudoTerminal.describe(errno: code))")
                break loop
            }
        }
        return UTF8StreamDecoder.lossyString(data)
    }

    /// `Foundation.Process` deliberately, to exercise ``PseudoTerminal`` independently of the runner.
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
