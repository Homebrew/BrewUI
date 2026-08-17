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
        let output = try await run(script: "test -t 1 && printf 'tty' || printf 'not-tty'", channel: .pseudoTerminal)

        #expect(output.standardOutput == "tty")
    }

    @Test func `pipe run leaves the child without a tty`() async throws {
        let output = try await run(script: "test -t 1 && printf 'tty' || printf 'not-tty'", channel: .pipes(forceColor: false))

        #expect(output.standardOutput == "not-tty")
    }

    @Test func `pseudo-terminal run sets TERM for the child`() async throws {
        // A GUI process launched from Finder inherits no TERM, and tools then suppress colour.
        let output = try await run(script: "printf '%s' \"$TERM\"", channel: .pseudoTerminal)

        #expect(output.standardOutput == "xterm-256color")
    }

    @Test func `pseudo-terminal run streams each line as it arrives`() async throws {
        let collector = OutputCollector()

        _ = try await run(
            script: "printf 'one\\ntwo\\nthree\\n'",
            channel: .pseudoTerminal,
            lineObserver: { collector.append($0) },
        )

        #expect(collector.allLines().map(\.text) == ["one", "two", "three"])
    }

    @Test func `pseudo-terminal run merges stderr into the stdout stream`() async throws {
        // One device carries both streams, so stderr cannot be told apart.
        let output = try await run(
            script: "printf 'out\\n'; printf 'err\\n' >&2",
            channel: .pseudoTerminal,
        )

        #expect(output.standardOutput.contains("out") && output.standardOutput.contains("err"))
    }

    @Test func `pseudo-terminal run leaves standardError empty`() async throws {
        let output = try await run(script: "printf 'err\\n' >&2", channel: .pseudoTerminal)

        #expect(output.standardError.isEmpty)
    }

    @Test func `a child reading stdin gets EOF instead of blocking on the terminal`() async throws {
        // An rc file reading stdin would block forever if stdin were the pty; it stays on /dev/null.
        let output = try await run(script: "read line; printf 'survived'", channel: .pseudoTerminal)

        #expect(output.standardOutput.contains("survived"))
    }

    @Test func `pseudo-terminal run reports a non-zero exit code`() async throws {
        let output = try await run(script: "exit 7", channel: .pseudoTerminal)

        #expect(output.terminationStatus == 7)
    }

    @Test func `pseudo-terminal run reports a signalled child as 128 plus the signal`() async throws {
        let output = try await run(script: "kill -TERM $$", channel: .pseudoTerminal)

        #expect(output.terminationStatus == 128 + SIGTERM)
    }

    @Test func `pseudo-terminal run resolves carriage-return redraws into settled text`() async throws {
        // The returned output is the assembled transcript, not the cursor script that produced it — the
        // raw bytes are asserted at the device level in PseudoTerminalTests.
        let output = try await run(script: "printf '10%%\\r50%%\\r100%%\\n'", channel: .pseudoTerminal)

        #expect(output.standardOutput == "100%\n")
    }

    @Test func `pseudo-terminal output is the diagnostic a failed run reports`() async throws {
        // The merged device leaves standardError empty, so this is the only account of the failure.
        let output = try await run(
            script: "printf 'Downloading\\n'; printf 'Error: no such cask\\n' >&2; exit 1",
            channel: .pseudoTerminal,
        )

        #expect(output.terminationStatus == 1)
        #expect(CommandFailureDetail.detail(from: output).contains("Error: no such cask"))
    }

    @Test func `pseudo-terminal run settles a trailing line lacking a newline`() async throws {
        let collector = OutputCollector()

        _ = try await run(
            script: "printf 'no-newline'",
            channel: .pseudoTerminal,
            lineObserver: { collector.append($0) },
        )

        let last = collector.allLines().last
        #expect(last?.text == "no-newline" && last?.isComplete == true)
    }

    @Test func `a progress redraw settles into one complete line`() async throws {
        let collector = OutputCollector()

        _ = try await run(
            script: "printf '10%%\\r50%%\\r100%%\\n'",
            channel: .pseudoTerminal,
            lineObserver: { collector.append($0) },
        )

        let settled = collector.allLines().filter(\.isComplete).map(\.text)
        #expect(settled == ["100%"])
    }

    @Test func `intermediate redraw states are reported as revisions`() async throws {
        let collector = OutputCollector()

        _ = try await run(
            script: "printf '10%%\\r'; sleep 0.1; printf '50%%\\r'; sleep 0.1; printf '100%%\\n'",
            channel: .pseudoTerminal,
            lineObserver: { collector.append($0) },
        )

        // Separated by sleeps so they arrive as distinct reads.
        let revisions = collector.allLines().filter { !$0.isComplete }.map(\.text)
        #expect(revisions == ["10%", "50%"])
    }

    @Test func `pseudo-terminal run survives output larger than the terminal buffer`() async throws {
        let output = try await run(
            script: "for i in $(seq 1 5000); do printf 'line %d\\n' $i; done",
            channel: .pseudoTerminal,
        )

        #expect(output.standardOutput.split(separator: "\n").count == 5000)
    }

    @Test func `cancelling a pseudo-terminal run stops the child`() async throws {
        let service = BrewCommandService()
        let task = Task {
            try await service.run(
                executableURL: URL(fileURLWithPath: "/bin/zsh"),
                arguments: ["-c", "sleep 30"],
                options: BrewRunOptions(output: .pseudoTerminal),
            )
        }

        try await Task.sleep(for: .milliseconds(200))
        task.cancel()

        // Returning at all is the assertion: an un-signalled child would hang for the full 30 seconds.
        let result = await task.result
        #expect(throws: Never.self) { try Self.assertCompleted(result) }
    }

    @Test func `cancelling a pseudo-terminal run also stops what the child spawned`() async throws {
        // Teardown signals the whole process group, so a cancelled install stops what it spawned.
        let service = BrewCommandService()
        let task = Task {
            try await service.run(
                executableURL: URL(fileURLWithPath: "/bin/zsh"),
                arguments: ["-c", "sleep \(Self.grandchildMarker) & wait"],
                options: BrewRunOptions(output: .pseudoTerminal),
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
        channel: BrewRunOptions.OutputChannel,
        lineObserver: (@Sendable (BrewCommandOutputLine) -> Void)? = nil,
    ) async throws -> CommandOutput {
        let service = BrewCommandService()
        return try await service.run(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-c", script],
            options: BrewRunOptions(lineObserver: lineObserver, output: channel),
        )
    }

    /// A cancelled run may throw or return a signalled status; both mean it stopped. Only a hang fails.
    static func assertCompleted(_ result: Result<CommandOutput, any Error>) throws {
        if case let .failure(error) = result, !(error is CancellationError) {
            throw error
        }
    }

    /// A unique needle for `pgrep`.
    static let grandchildMarker = "31337"

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

/// `run` only returns after every sink call has been made, so all lines are recorded by the time a test
/// reads them.
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
