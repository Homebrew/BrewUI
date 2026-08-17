//
//  TerminalProgressIntegrationTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Testing

/// End to end: a real subprocess writing terminal redraws, through the drain and assembler, into the
/// console's job buffer.
@Suite(.serialized)
struct TerminalProgressIntegrationTests {
    /// A `curl`-style bar redrawing hundreds of times, padded to width, with no newline until it ends.
    private static let downloadScript = """
    printf '==> Downloading https://ghcr.io/v2/homebrew/core/go/manifests/1.26.5\\n'
    for i in $(seq 1 600); do
      printf '######################   %s.0 pct\\r' $i
    done
    printf '#########################  100.0 pct\\n'
    printf 'Downloaded to: /Users/x/Library/Caches/Homebrew/downloads/go.tar.gz\\n'
    printf '==> Pouring go--1.26.5.arm64_tahoe.bottle.tar.gz\\n'
    """

    @Test func `a download's redraws settle into the rows a terminal would show`() async throws {
        let rows = try await runIntoJob(script: Self.downloadScript).map(\.text)

        #expect(rows == [
            "==> Downloading https://ghcr.io/v2/homebrew/core/go/manifests/1.26.5",
            "#########################  100.0 pct",
            "Downloaded to: /Users/x/Library/Caches/Homebrew/downloads/go.tar.gz",
            "==> Pouring go--1.26.5.arm64_tahoe.bottle.tar.gz",
        ])
    }

    @Test func `every row in a finished job is settled`() async throws {
        let rows = try await runIntoJob(script: Self.downloadScript)

        #expect(rows.filter { !$0.isComplete }.isEmpty)
    }

    @Test func `a bar still being drawn occupies exactly one row`() async throws {
        let script = "for i in $(seq 1 50); do printf '#### %s pct\\r' $i; done; sleep 0.2"
        let rows = try await runIntoJob(script: script)

        #expect(rows.count == 1 && rows[0].isComplete)
    }
}

private extension TerminalProgressIntegrationTests {
    /// Replays the streamed lines into a ``CommandJob`` as the console does, returning the rows a user
    /// would see.
    func runIntoJob(script: String) async throws -> [BrewCommandOutputLine] {
        let collector = LineCollector()
        let service = BrewCommandService()

        _ = try await service.run(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-c", script],
            options: BrewRunOptions(lineObserver: { collector.append($0) }, output: .pseudoTerminal),
        )

        return await MainActor.run {
            let job = CommandJob(
                operationID: BrewOperationID(kind: .formula, name: "go"),
                command: "brew upgrade go",
                startedAt: Date(),
                phase: .running(.upgradeFormula),
            )
            for line in collector.allLines() {
                job.appendOutput(line)
            }
            return job.output
        }
    }
}

// swiftlint:disable:next unchecked_sendable
private final class LineCollector: @unchecked Sendable {
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
