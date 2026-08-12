//
//  BrewCommandServiceTerminalFallbackTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import Foundation
import Testing

/// A run that asks for a terminal but cannot get one degrades to pipes rather than failing. The pty
/// device pool is far smaller than `kern.tty.ptmx_max` advertises, so allocation failure is a real
/// environmental outcome, and losing Homebrew's progress rendering beats losing the install.
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
        // Pipes carry the two streams separately, unlike the single device a terminal presents.
        let output = try await runWithUnavailableTerminal(
            script: "printf 'out' ; printf 'err' >&2",
        )

        #expect(output.standardOutput == "out" && output.standardError == "err")
    }

    @Test func `the fallback still asks Homebrew for colour`() async throws {
        // The terminal was what supplied colour; without it Homebrew has to be told, or a display run
        // would silently lose its colouring as well as its progress rendering.
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
        // Only allocation failure degrades; a command that cannot run must still fail.
        let service = BrewCommandService(makeTerminal: { throw TerminalUnavailable() })

        await #expect(throws: (any Error).self) {
            try await service.run(
                executableURL: URL(fileURLWithPath: "/nonexistent/executable"),
                arguments: [],
                options: BrewRunOptions(usesPseudoTerminal: true),
            )
        }
    }

    @Test func `the fallback options drop the terminal and force colour`() {
        // Asserted on the shaping directly rather than by reading HOMEBREW_COLOR out of a child, which
        // would depend on whatever the developer happens to export.
        let fallback = BrewCommandService.colourisedPipeFallback(
            from: BrewRunOptions(forceColor: false, usesPseudoTerminal: true),
        )

        #expect(fallback.usesPseudoTerminal == false && fallback.forceColor)
    }

    @Test func `the fallback options keep the caller's line observer`() {
        // Losing the observer here would silently stop the console streaming on the degraded path.
        let fallback = BrewCommandService.colourisedPipeFallback(
            from: BrewRunOptions(lineObserver: { _ in }, usesPseudoTerminal: true),
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
            options: BrewRunOptions(lineObserver: lineObserver, usesPseudoTerminal: true),
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
