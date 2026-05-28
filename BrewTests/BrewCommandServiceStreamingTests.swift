//
//  BrewCommandServiceStreamingTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

nonisolated struct BrewCommandServiceStreamingTests {
    @Test func `run with task-local sink emits each stdout line as it arrives`() async throws {
        let service = BrewCommandService()
        let executable = URL(fileURLWithPath: "/bin/zsh")
        let collector = OutputCollector()

        let sink: @Sendable (BrewCommandOutputLine) -> Void = { line in
            collector.append(line)
        }
        let output: CommandOutput = try await BrewCommandOutputContext.$sink.withValue(sink) {
            try await service.run(
                executableURL: executable,
                arguments: ["-lc", "printf 'one\\ntwo\\nthree\\n'"],
            )
        }

        #expect(output.standardOutput == "one\ntwo\nthree\n")
        let lines = collector.allLines()
        let stdoutLines = lines.filter { $0.stream == .stdout }.map(\.text)
        #expect(stdoutLines == ["one", "two", "three"])
    }

    @Test func `run with task-local sink flushes trailing line lacking newline`() async throws {
        let service = BrewCommandService()
        let executable = URL(fileURLWithPath: "/bin/zsh")
        let collector = OutputCollector()

        let sink: @Sendable (BrewCommandOutputLine) -> Void = { line in
            collector.append(line)
        }
        let output: CommandOutput = try await BrewCommandOutputContext.$sink.withValue(sink) {
            try await service.run(
                executableURL: executable,
                arguments: ["-lc", "printf 'hello-out'; printf 'hello-err' >&2"],
            )
        }

        #expect(output.standardOutput == "hello-out")
        #expect(output.standardError == "hello-err")
        let lines = collector.allLines()
        #expect(lines.contains { $0.stream == .stdout && $0.text == "hello-out" })
        #expect(lines.contains { $0.stream == .stderr && $0.text == "hello-err" })
    }

    @Test func `run with task-local sink separates stdout and stderr streams`() async throws {
        let service = BrewCommandService()
        let executable = URL(fileURLWithPath: "/bin/zsh")
        let collector = OutputCollector()

        let sink: @Sendable (BrewCommandOutputLine) -> Void = { line in
            collector.append(line)
        }
        _ = try await BrewCommandOutputContext.$sink.withValue(sink) {
            try await service.run(
                executableURL: executable,
                arguments: ["-lc", "printf 'out1\\n'; printf 'err1\\n' >&2; printf 'out2\\n'"],
            )
        }

        let lines = collector.allLines()
        let stdout = lines.filter { $0.stream == .stdout }.map(\.text)
        let stderr = lines.filter { $0.stream == .stderr }.map(\.text)
        #expect(stdout == ["out1", "out2"])
        #expect(stderr == ["err1"])
    }

    @Test func `run without task-local sink preserves byte-exact CommandOutput`() async throws {
        let service = BrewCommandService()
        let executable = URL(fileURLWithPath: "/bin/zsh")

        let output = try await service.run(
            executableURL: executable,
            arguments: ["-lc", "printf 'hello-out'; printf 'hello-err' >&2"],
        )

        #expect(output.terminationStatus == 0)
        #expect(output.standardOutput == "hello-out")
        #expect(output.standardError == "hello-err")
    }
}

/// Thread-safe collector for streamed lines. Appends synchronously (under a lock) inside the sink, so
/// that — because `BrewCommandService.run` only returns after every sink call has been made — all lines
/// are recorded by the time a test reads them, with no racing detached Tasks.
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
