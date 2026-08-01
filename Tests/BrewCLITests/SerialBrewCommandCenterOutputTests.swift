//
//  SerialBrewCommandCenterOutputTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import BrewServicesTestSupport
import Foundation
import Testing

private actor AllOutputCollector {
    private(set) var events: [(BrewOperationID, BrewCommandOutputLine)] = []

    func append(id: BrewOperationID, line: BrewCommandOutputLine) {
        events.append((id, line))
    }
}

/// Runner that emits a fixed set of lines (keyed by argv) through the run options' observer — exercises the
/// streaming plumbing without a real subprocess. Commands are inert data, so the lines live on the runner.
private struct LineEmittingRunner: BrewCommandRunning {
    let linesFor: @Sendable ([String]) -> [(BrewCommandOutputLine.Stream, String)]

    func run(executableURL _: URL, arguments: [String], options: BrewRunOptions) async throws -> CommandOutput {
        for (stream, text) in linesFor(arguments) {
            options.lineObserver?(BrewCommandOutputLine(stream: stream, text: text))
            try await Task.sleep(for: .milliseconds(2))
        }
        return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }
}

private func makeOutputTestCenter(
    _ linesFor: @escaping @Sendable ([String]) -> [(BrewCommandOutputLine.Stream, String)],
) -> SerialBrewCommandCenter {
    let ctx = BrewCommandExecutionContext(
        commandRunner: LineEmittingRunner(linesFor: linesFor),
        locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/fake/brew")),
    )
    return SerialBrewCommandCenter(executionContext: ctx)
}

private func command(_ argv: String) -> BrewCommand {
    BrewCommand(operationKind: .upgradeFormula, arguments: [argv])
}

struct SerialBrewCommandCenterOutputTests {
    @Test func `output for an id delivers lines emitted via the runner in order`() async throws {
        let center = makeOutputTestCenter { _ in
            [(.stdout, "one"), (.stdout, "two"), (.stderr, "warn"), (.stdout, "three")]
        }
        let id = BrewOperationID(kind: .formula, name: "output-order")
        let stream = await center.allOutputChanges()
        let collector = AllOutputCollector()
        let collect = Task {
            for await pair in stream {
                await collector.append(id: pair.0, line: pair.1)
            }
        }
        defer { collect.cancel() }

        try await center.capture(command("go"), id: id)
        try await Task.sleep(for: .milliseconds(80))

        let lines = await collector.events.filter { $0.0 == id }.map(\.1)
        #expect(lines.map(\.text) == ["one", "two", "warn", "three"])
        #expect(lines.map(\.stream) == [.stdout, .stdout, .stderr, .stdout])
    }

    @Test func `allOutputChanges emits lines for any id with no initial replay`() async throws {
        let center = makeOutputTestCenter { argv in
            argv == ["a"] ? [(.stdout, "a1"), (.stdout, "a2")] : [(.stdout, "b1")]
        }
        let idA = BrewOperationID(kind: .formula, name: "all-a")
        let idB = BrewOperationID(kind: .formula, name: "all-b")
        let stream = await center.allOutputChanges()
        let collector = AllOutputCollector()
        let collect = Task {
            for await pair in stream {
                await collector.append(id: pair.0, line: pair.1)
            }
        }
        defer { collect.cancel() }

        try await center.capture(command("a"), id: idA)
        try await center.capture(command("b"), id: idB)
        try await Task.sleep(for: .milliseconds(80))

        let events = await collector.events
        #expect(events.filter { $0.0 == idA }.map(\.1.text) == ["a1", "a2"])
        #expect(events.filter { $0.0 == idB }.map(\.1.text) == ["b1"])
    }

    @Test func `output multicasts to multiple subscribers`() async throws {
        let center = makeOutputTestCenter { _ in [(.stdout, "x"), (.stdout, "y")] }
        let id = BrewOperationID(kind: .formula, name: "output-multi")
        let streamA = await center.allOutputChanges()
        let streamB = await center.allOutputChanges()
        let collectorA = AllOutputCollector()
        let collectorB = AllOutputCollector()
        let taskA = Task {
            for await pair in streamA {
                await collectorA.append(id: pair.0, line: pair.1)
            }
        }
        let taskB = Task {
            for await pair in streamB {
                await collectorB.append(id: pair.0, line: pair.1)
            }
        }
        defer {
            taskA.cancel()
            taskB.cancel()
        }

        try await center.capture(command("go"), id: id)
        try await Task.sleep(for: .milliseconds(80))

        let textsA = await collectorA.events.map(\.1.text)
        let textsB = await collectorB.events.map(\.1.text)
        #expect(textsA == ["x", "y"])
        #expect(textsB == ["x", "y"])
    }

    @Test func `output listener removed on stream termination`() async throws {
        let center = makeOutputTestCenter { _ in [(.stdout, "lost")] }
        let id = BrewOperationID(kind: .formula, name: "output-cleanup")
        let stream = await center.allOutputChanges()
        let collector = AllOutputCollector()
        let collect = Task {
            for await pair in stream {
                await collector.append(id: pair.0, line: pair.1)
            }
        }
        collect.cancel()
        try await Task.sleep(for: .milliseconds(20))

        try await center.capture(command("go"), id: id)
        try await Task.sleep(for: .milliseconds(80))

        let events = await collector.events
        #expect(events.isEmpty)
    }
}
