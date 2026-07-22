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

/// Emits a fixed set of lines through ``BrewCommandOutputContext/sink`` — exercises the sink
/// plumbing without invoking a real subprocess.
private struct EmitOutputCommand: BrewMutatingCommand {
    let lines: [(BrewCommandOutputLine.Stream, String)]

    var operationKind: BrewOperationKind {
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
    @Test func `output for an id delivers lines emitted via the sink in order`() async throws {
        let center = makeOutputTestCenter()
        let id = BrewOperationID(kind: .formula, name: "output-order")
        let stream = await center.allOutputChanges()
        let collector = AllOutputCollector()
        let collect = Task {
            for await pair in stream {
                await collector.append(id: pair.0, line: pair.1)
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

        let lines = await collector.events.filter { $0.0 == id }.map(\.1)
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

    @Test func `output multicasts to multiple subscribers`() async throws {
        let center = makeOutputTestCenter()
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

        try await center.submit(
            id: id,
            command: EmitOutputCommand(lines: [(.stdout, "x"), (.stdout, "y")]),
        )
        try await Task.sleep(for: .milliseconds(80))

        let textsA = await collectorA.events.map(\.1.text)
        let textsB = await collectorB.events.map(\.1.text)
        #expect(textsA == ["x", "y"])
        #expect(textsB == ["x", "y"])
    }

    @Test func `output listener removed on stream termination`() async throws {
        let center = makeOutputTestCenter()
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

        try await center.submit(
            id: id,
            command: EmitOutputCommand(lines: [(.stdout, "lost")]),
        )
        try await Task.sleep(for: .milliseconds(80))

        let events = await collector.events
        #expect(events.isEmpty)
    }
}
