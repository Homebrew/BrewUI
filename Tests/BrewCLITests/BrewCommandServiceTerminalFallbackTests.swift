//
//  BrewCommandServiceTerminalFallbackTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import Foundation
import Testing

/// A run that asks for a terminal but cannot get one degrades to pipes rather than failing: the device
/// pool is small, so allocation failure is a real outcome, and losing progress rendering beats losing
/// the install.
struct BrewCommandServiceTerminalFallbackTests {
    @Test func `a run whose terminal cannot be allocated still succeeds`() async throws {
        let output = try await runWithUnavailableTerminal(script: "printf 'ran anyway'")

        #expect(output.standardOutput == "ran anyway" && output.terminationStatus == 0)
    }

    @Test func `the fallback runs on pipes, so the child sees no terminal`() async throws {
        let output = try await runWithUnavailableTerminal(
            script: "test -t 1 && printf 'tty' || printf 'not-tty'",
        )

        #expect(output.standardOutput == "not-tty")
    }

    @Test func `the fallback keeps stdout and stderr apart`() async throws {
        let output = try await runWithUnavailableTerminal(
            script: "printf 'out' ; printf 'err' >&2",
        )

        #expect(output.standardOutput == "out" && output.standardError == "err")
    }

    @Test func `the fallback still asks Homebrew for colour`() async throws {
        // The terminal was what supplied colour, so without it Homebrew has to be told.
        let output = try await runWithUnavailableTerminal(script: "printf '%s' \"$HOMEBREW_COLOR\"")

        #expect(output.standardOutput == "1")
    }

    @Test func `the fallback still streams lines`() async throws {
        let collector = FallbackCollector()
        _ = try await runWithUnavailableTerminal(
            script: "printf 'one\\ntwo\\n'",
            lineObserver: { collector.append($0) },
        )

        #expect(collector.allLines().map(\.text) == ["one", "two"])
    }

    @Test func `a genuine launch failure is not swallowed by the fallback`() async throws {
        let service = BrewCommandService(makeTerminal: { throw TerminalUnavailable() })

        await #expect(throws: (any Error).self) {
            try await service.run(
                executableURL: URL(fileURLWithPath: "/nonexistent/executable"),
                arguments: [],
                options: BrewRunOptions(output: .pseudoTerminal),
            )
        }
    }

    @Test func `the fallback options drop the terminal and force colour`() {
        // Asserted on the shaping rather than reading HOMEBREW_COLOR out of a child, which would depend
        // on whatever the developer exports.
        let fallback = BrewCommandService.pipeFallback(
            from: BrewRunOptions(output: .pseudoTerminal),
        )

        #expect(fallback.output == .pipes(forceColor: true))
    }

    @Test func `the fallback options keep the caller's line observer`() {
        let fallback = BrewCommandService.pipeFallback(
            from: BrewRunOptions(lineObserver: { _ in }, output: .pseudoTerminal),
        )

        #expect(fallback.lineObserver != nil)
    }
}

private extension BrewCommandServiceTerminalFallbackTests {
    func runWithUnavailableTerminal(
        script: String,
        lineObserver: (@Sendable (BrewCommandOutputLine) -> Void)? = nil,
    ) async throws -> CommandOutput {
        let service = BrewCommandService(makeTerminal: { throw TerminalUnavailable() })
        return try await service.run(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-c", script],
            options: BrewRunOptions(lineObserver: lineObserver, output: .pseudoTerminal),
        )
    }
}

private struct TerminalUnavailable: Error {}

// swiftlint:disable:next unchecked_sendable
private final class FallbackCollector: @unchecked Sendable {
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
