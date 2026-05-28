//
//  SerialBrewCommandCenterOutputTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import BrewCoreTestSupport
import BrewServicesTestSupport
import Foundation
import Testing

private actor OutputLineCollector {
    private(set) var lines: [BrewCommandOutputLine] = []

    func append(_ line: BrewCommandOutputLine) {
        lines.append(line)
    }
}

private actor AllOutputCollector {
    private(set) var events: [(BrewOperationID, BrewCommandOutputLine)] = []

    func append(id: BrewOperationID, line: BrewCommandOutputLine) {
        events.append((id, line))
    }
}

/// Emits a fixed set of lines through ``BrewCommandOutputContext/sink`` — exercises the sink
/// plumbing without invoking a real subprocess.
private struct EmitOutputCommand: BrewMutatingCommand {
    let lines: [(BrewCommandOutputLine.Stream, String)]

    nonisolated var operationKind: BrewOperationKind {
        .upgradeFormula
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        _ = context
        for (stream, text) in lines {
            BrewCommandOutputContext.sink?(BrewCommandOutputLine(stream: stream, text: text))
            try await Task.sleep(for: .milliseconds(2))
        }
    }
}

private func makeOutputTestCenter() -> SerialBrewCommandCenter {
    let ctx = BrewCommandExecutionContext(
        commandRunner: MockBrewCommandRunner(responses: [:]),
        locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/fake/brew")),
    )
    return SerialBrewCommandCenter(executionContext: ctx)
}

struct SerialBrewCommandCenterOutputTests {
    @Test func `outputChanges for id delivers lines emitted via the sink in order`() async throws {
        let center = makeOutputTestCenter()
        let id = BrewOperationID(kind: .formula, name: "output-order")
        let stream = await center.outputChanges(for: id)
        let collector = OutputLineCollector()
        let collect = Task {
            for await line in stream {
                await collector.append(line)
            }
        }
        defer { collect.cancel() }

        try await center.submit(
            id: id,
            command: EmitOutputCommand(lines: [
                (.stdout, "one"),
                (.stdout, "two"),
                (.stderr, "warn"),
                (.stdout, "three"),
            ]),
        )
        try await Task.sleep(for: .milliseconds(80))

        let lines = await collector.lines
        #expect(lines.map(\.text) == ["one", "two", "warn", "three"])
        #expect(lines.map(\.stream) == [.stdout, .stdout, .stderr, .stdout])
    }

    @Test func `allOutputChanges emits lines for any id with no initial replay`() async throws {
        let center = makeOutputTestCenter()
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

        try await center.submit(
            id: idA,
            command: EmitOutputCommand(lines: [(.stdout, "a1"), (.stdout, "a2")]),
        )
        try await center.submit(
            id: idB,
            command: EmitOutputCommand(lines: [(.stdout, "b1")]),
        )
        try await Task.sleep(for: .milliseconds(80))

        let events = await collector.events
        let textsA = events.filter { $0.0 == idA }.map(\.1.text)
        let textsB = events.filter { $0.0 == idB }.map(\.1.text)
        #expect(textsA == ["a1", "a2"])
        #expect(textsB == ["b1"])
    }

    @Test func `outputChanges multicasts to multiple subscribers`() async throws {
        let center = makeOutputTestCenter()
        let id = BrewOperationID(kind: .formula, name: "output-multi")
        let streamA = await center.outputChanges(for: id)
        let streamB = await center.outputChanges(for: id)
        let collectorA = OutputLineCollector()
        let collectorB = OutputLineCollector()
        let taskA = Task {
            for await line in streamA {
                await collectorA.append(line)
            }
        }
        let taskB = Task {
            for await line in streamB {
                await collectorB.append(line)
            }
        }
        defer {
            taskA.cancel()
            taskB.cancel()
        }

        try await center.submit(
            id: id,
            command: EmitOutputCommand(lines: [(.stdout, "x"), (.stdout, "y")]),
        )
        try await Task.sleep(for: .milliseconds(80))

        let textsA = await collectorA.lines.map(\.text)
        let textsB = await collectorB.lines.map(\.text)
        #expect(textsA == ["x", "y"])
        #expect(textsB == ["x", "y"])
    }

    @Test func `output listener removed on stream termination`() async throws {
        let center = makeOutputTestCenter()
        let id = BrewOperationID(kind: .formula, name: "output-cleanup")
        let stream = await center.outputChanges(for: id)
        let collector = OutputLineCollector()
        let collect = Task {
            for await line in stream {
                await collector.append(line)
            }
        }
        collect.cancel()
        try await Task.sleep(for: .milliseconds(20))

        try await center.submit(
            id: id,
            command: EmitOutputCommand(lines: [(.stdout, "lost")]),
        )
        try await Task.sleep(for: .milliseconds(80))

        let lines = await collector.lines
        #expect(lines.isEmpty)
    }
}
