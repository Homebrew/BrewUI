//
//  BrewCommandServicePseudoTerminalTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import Foundation
import Testing

@Suite(.serialized)
struct BrewCommandServicePseudoTerminalTests {
    @Test func `pseudo-terminal run gives the child a tty on stdout`() async throws {
        let output = try await run(script: "test -t 1 && printf 'tty' || printf 'not-tty'", usesPseudoTerminal: true)

        #expect(output.standardOutput == "tty")
    }

    @Test func `pipe run leaves the child without a tty`() async throws {
        // The contrast that justifies the whole feature: same command, same runner, no terminal.
        let output = try await run(script: "test -t 1 && printf 'tty' || printf 'not-tty'", usesPseudoTerminal: false)

        #expect(output.standardOutput == "not-tty")
    }

    @Test func `pseudo-terminal run sets TERM for the child`() async throws {
        // A GUI process launched from Finder inherits no TERM; without one, tools treat the terminal as
        // capability-less and suppress exactly the colour and progress output the pty was allocated for.
        let output = try await run(script: "printf '%s' \"$TERM\"", usesPseudoTerminal: true)

        #expect(output.standardOutput == "xterm-256color")
    }

    @Test func `pseudo-terminal run streams each line as it arrives`() async throws {
        let collector = OutputCollector()

        _ = try await run(
            script: "printf 'one\\ntwo\\nthree\\n'",
            usesPseudoTerminal: true,
            lineObserver: { collector.append($0) },
        )

        #expect(collector.allLines().map(\.text) == ["one", "two", "three"])
    }

    @Test func `pseudo-terminal run merges stderr into the stdout stream`() async throws {
        // Documents the trade-off rather than a preference: one terminal device carries both streams, so
        // stderr cannot be told apart. Runs whose output is parsed stay on pipes for this reason.
        let output = try await run(
            script: "printf 'out\\n'; printf 'err\\n' >&2",
            usesPseudoTerminal: true,
        )

        #expect(output.standardOutput.contains("out") && output.standardOutput.contains("err"))
    }

    @Test func `pseudo-terminal run leaves standardError empty`() async throws {
        let output = try await run(script: "printf 'err\\n' >&2", usesPseudoTerminal: true)

        #expect(output.standardError.isEmpty)
    }

    @Test func `a child reading stdin gets EOF instead of blocking on the terminal`() async throws {
        // The hang worth guarding against: an interactive rc file that reads stdin would block forever if
        // stdin were wired to the pty, since nothing ever writes to it. It stays on /dev/null instead.
        let output = try await run(script: "read line; printf 'survived'", usesPseudoTerminal: true)

        #expect(output.standardOutput.contains("survived"))
    }

    @Test func `pseudo-terminal run reports a non-zero exit code`() async throws {
        let output = try await run(script: "exit 7", usesPseudoTerminal: true)

        #expect(output.terminationStatus == 7)
    }

    @Test func `pseudo-terminal run reports a signalled child as 128 plus the signal`() async throws {
        let output = try await run(script: "kill -TERM $$", usesPseudoTerminal: true)

        #expect(output.terminationStatus == 128 + SIGTERM)
    }

    @Test func `pseudo-terminal run preserves carriage-return progress redraws`() async throws {
        // The payoff case: a progress meter rewriting one line arrives byte-for-byte, ready for a console
        // that interprets \r. The kernel's own \n → \r\n rewrite stays off, so the only \r is the child's.
        let output = try await run(script: "printf '10%%\\r50%%\\r100%%\\n'", usesPseudoTerminal: true)

        #expect(output.standardOutput == "10%\r50%\r100%\n")
    }

    @Test func `pseudo-terminal run settles a trailing line lacking a newline`() async throws {
        let collector = OutputCollector()

        _ = try await run(
            script: "printf 'no-newline'",
            usesPseudoTerminal: true,
            lineObserver: { collector.append($0) },
        )

        // Reported first as an in-progress revision, then settled when the stream ends.
        let last = collector.allLines().last
        #expect(last?.text == "no-newline" && last?.isComplete == true)
    }

    @Test func `a progress redraw settles into one complete line`() async throws {
        // The reported bug, end to end: many carriage-return redraws must leave one settled line, with
        // the intermediate states reported as revisions of it rather than as separate lines.
        let collector = OutputCollector()

        _ = try await run(
            script: "printf '10%%\\r50%%\\r100%%\\n'",
            usesPseudoTerminal: true,
            lineObserver: { collector.append($0) },
        )

        let settled = collector.allLines().filter(\.isComplete).map(\.text)
        #expect(settled == ["100%"])
    }

    @Test func `intermediate redraw states are reported as revisions`() async throws {
        let collector = OutputCollector()

        _ = try await run(
            script: "printf '10%%\\r'; sleep 0.1; printf '50%%\\r'; sleep 0.1; printf '100%%\\n'",
            usesPseudoTerminal: true,
            lineObserver: { collector.append($0) },
        )

        // Separated by sleeps so they arrive as distinct reads, which is what a real download looks like.
        let revisions = collector.allLines().filter { !$0.isComplete }.map(\.text)
        #expect(revisions == ["10%", "50%"])
    }

    @Test func `pseudo-terminal run survives output larger than the terminal buffer`() async throws {
        // A pty's kernel buffer is far smaller than a pipe's, so a stalled drain would deadlock here.
        let output = try await run(
            script: "for i in $(seq 1 5000); do printf 'line %d\\n' $i; done",
            usesPseudoTerminal: true,
        )

        #expect(output.standardOutput.split(separator: "\n").count == 5000)
    }

    @Test func `cancelling a pseudo-terminal run stops the child`() async throws {
        let service = BrewCommandService()
        let task = Task {
            try await service.run(
                executableURL: URL(fileURLWithPath: "/bin/zsh"),
                arguments: ["-c", "sleep 30"],
                options: BrewRunOptions(usesPseudoTerminal: true),
            )
        }

        // Give the spawn a moment to get as far as the child before cancelling it.
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()

        // The assertion is that this returns at all: an unreaped drain or an un-signalled child would
        // leave the await hanging for the full 30 seconds.
        let result = await task.result
        #expect(throws: Never.self) { try Self.assertCompleted(result) }
    }

    @Test func `cancelling a pseudo-terminal run also stops what the child spawned`() async throws {
        // The reason the run creates its own session: teardown signals the whole process group, so a
        // cancelled install stops the curl or git it was waiting on instead of orphaning it.
        let service = BrewCommandService()
        let task = Task {
            try await service.run(
                executableURL: URL(fileURLWithPath: "/bin/zsh"),
                arguments: ["-c", "sleep \(Self.grandchildMarker) & wait"],
                options: BrewRunOptions(usesPseudoTerminal: true),
            )
        }

        try await Task.sleep(for: .milliseconds(500))
        let spawned = Self.grandchildCount()
        task.cancel()
        _ = await task.result
        try await Task.sleep(for: .milliseconds(1500))

        #expect(spawned > 0 && Self.grandchildCount() == 0)
    }
}

private extension BrewCommandServicePseudoTerminalTests {
    func run(
        script: String,
        usesPseudoTerminal: Bool,
        lineObserver: (@Sendable (BrewCommandOutputLine) -> Void)? = nil,
    ) async throws -> CommandOutput {
        let service = BrewCommandService()
        return try await service.run(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-c", script],
            options: BrewRunOptions(lineObserver: lineObserver, usesPseudoTerminal: usesPseudoTerminal),
        )
    }

    /// A cancelled run may either throw or return a signalled status; both are "it stopped". Only a hang
    /// would fail the test, by never producing a result at all.
    static func assertCompleted(_ result: Result<CommandOutput, any Error>) throws {
        if case let .failure(error) = result, !(error is CancellationError) {
            throw error
        }
    }

    /// An implausible sleep duration, used purely as a unique needle for `pgrep`.
    static let grandchildMarker = "31337"

    /// How many grandchildren carrying the marker are currently alive.
    static func grandchildCount() -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "sleep \(grandchildMarker)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (String(bytes: data, encoding: .utf8) ?? "").split(separator: "\n").count
    }
}

/// Thread-safe collector for streamed lines. Appends synchronously (under a lock) inside the sink, so that
/// — because `BrewCommandService.run` only returns after every sink call has been made — all lines are
/// recorded by the time a test reads them.
// swiftlint:disable:next unchecked_sendable
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [BrewCommandOutputLine] = []

    func append(_ line: BrewCommandOutputLine) {
        lock.lock()
        defer { lock.unlock() }
        lines.append(line)
    }

    func allLines() -> [BrewCommandOutputLine] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }
}
