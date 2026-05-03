//
//  SerialBrewCommandCenterTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct SerialBrewCommandCenterTests {
    private func makeCenter() -> SerialBrewCommandCenter {
        let ctx = BrewCommandExecutionContext(
            commandRunner: MockBrewCommandRunner(responses: [:]),
            locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/fake/brew")),
        )
        return SerialBrewCommandCenter(executionContext: ctx)
    }

    @Test func `serializes operations so second runs after first`() async throws {
        let center = makeCenter()
        let idA = BrewOperationID(kind: .formula, name: "a")
        let idB = BrewOperationID(kind: .formula, name: "b")
        let collector = OrderCollector()

        try await center.submit(
            id: idA,
            command: OrderingSleepCommand(collector: collector, prefix: "a"),
        )
        try await center.submit(
            id: idB,
            command: AppendTokenCommand(collector: collector, token: "b"),
        )

        let order = await collector.snapshot()
        #expect(order == ["a-start", "a-end", "b"])
    }

    @Test func `duplicate id coalesces to a single command body`() async throws {
        let center = makeCenter()
        let id = BrewOperationID(kind: .formula, name: "git")
        let counter = InvocationCounter()

        let first = Task {
            try await center.submit(
                id: id,
                command: SlowIncrementCommand(counter: counter),
            )
        }
        try await Task.sleep(for: .milliseconds(5))
        let second = Task {
            try await center.submit(
                id: id,
                command: SlowIncrementCommand(counter: counter),
            )
        }

        try await first.value
        try await second.value
        let count = await counter.value
        #expect(count == 1)
    }

    @Test func `clears running phase on success`() async throws {
        let center = makeCenter()
        let id = BrewOperationID(rawValue: "formula:ok")
        #expect(await center.phase(for: id) == .idle)

        try await center.submit(id: id, command: EmptyMutatingCommand())

        #expect(await center.phase(for: id) == .idle)
        #expect(await !center.isActive(id: id))
    }

    @Test func `records failure with OperationFailure and clears in flight slot`() async throws {
        let center = makeCenter()
        let id = BrewOperationID(rawValue: "formula:bad")

        do {
            try await center.submit(id: id, command: ThrowingMutatingCommand())
            Issue.record("expected submit to throw")
        } catch {
            _ = error
        }

        let phase = await center.phase(for: id)
        guard case let .failed(reason: failure) = phase else {
            Issue.record("expected failed phase")
            return
        }
        #expect(!failure.userFacingMessage.isEmpty)
        #expect(await !center.isActive(id: id))
    }

    @Test func `phaseByID exposes tracked entries`() async throws {
        let center = makeCenter()
        let id = BrewOperationID(rawValue: "formula:snapshot")
        #expect(await center.phaseByID().isEmpty)

        do {
            try await center.submit(id: id, command: ThrowingMutatingCommand())
        } catch {
            _ = error
        }

        let map = await center.phaseByID()
        #expect(map[id] != nil)
        #expect(await center.phase(for: id) == map[id])
    }

    @Test func `mutating command uses injected mock runner not real brew`() async throws {
        let argv = ["upgrade", "demo-formula"]
        let runner = MockBrewCommandRunner(responses: [
            argv: CommandOutput(standardOutput: "mock-ok", standardError: "", terminationStatus: 0),
        ])
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: InstalledPackagesTestSupport.fakeBrewExecutableURL),
        )
        let center = SerialBrewCommandCenter(executionContext: ctx)
        let id = BrewOperationID(rawValue: "formula:demo-formula")

        try await center.submit(id: id, command: RunMockedArgvCommand(arguments: argv))

        #expect(await center.phase(for: id) == .idle)
    }

    @Test func `recording wrapper logs each submit while duplicate id coalesces body`() async throws {
        let ctx = BrewCommandExecutionContext(
            commandRunner: MockBrewCommandRunner(responses: [:]),
            locator: BrewExecutableLocator(overrideURL: InstalledPackagesTestSupport.fakeBrewExecutableURL),
        )
        let center = RecordingSerialBrewCommandCenter(executionContext: ctx)
        let id = BrewOperationID(kind: .formula, name: "git")
        let counter = InvocationCounter()

        let first = Task {
            try await center.submit(
                id: id,
                command: SlowIncrementCommand(counter: counter),
            )
        }
        try await Task.sleep(for: .milliseconds(5))
        let second = Task {
            try await center.submit(
                id: id,
                command: SlowIncrementCommand(counter: counter),
            )
        }

        try await first.value
        try await second.value

        let log = await center.recordedSubmitEntries
        #expect(log.count == 2)
        #expect(log.allSatisfy { $0.id == id && $0.kind == .upgradeFormula })
        #expect(await counter.value == 1)
    }
}

// MARK: - Test commands

private struct EmptyMutatingCommand: BrewMutatingCommand {
    nonisolated var operationKind: BrewOperationKind {
        .upgradeFormula
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        _ = context
    }
}

private struct ThrowingMutatingCommand: BrewMutatingCommand {
    struct TestError: Error {}

    nonisolated var operationKind: BrewOperationKind {
        .upgradeFormula
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        _ = context
        throw TestError()
    }
}

private actor OrderCollector {
    private var order: [String] = []

    func append(_ token: String) {
        order.append(token)
    }

    func snapshot() -> [String] {
        order
    }
}

private struct OrderingSleepCommand: BrewMutatingCommand {
    let collector: OrderCollector
    let prefix: String

    nonisolated var operationKind: BrewOperationKind {
        .upgradeFormula
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        _ = context
        await collector.append("\(prefix)-start")
        try await Task.sleep(for: .milliseconds(20))
        await collector.append("\(prefix)-end")
    }
}

private struct AppendTokenCommand: BrewMutatingCommand {
    let collector: OrderCollector
    let token: String

    nonisolated var operationKind: BrewOperationKind {
        .upgradeFormula
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        _ = context
        await collector.append(token)
    }
}

private actor InvocationCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private struct SlowIncrementCommand: BrewMutatingCommand {
    let counter: InvocationCounter

    nonisolated var operationKind: BrewOperationKind {
        .upgradeFormula
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        _ = context
        await counter.increment()
        try await Task.sleep(for: .milliseconds(30))
    }
}

private struct RunMockedArgvCommand: BrewMutatingCommand {
    let arguments: [String]

    nonisolated var operationKind: BrewOperationKind {
        .upgradeFormula
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        let url = try context.brewExecutableURL()
        let out = try await context.commandRunner.run(executableURL: url, arguments: arguments)
        #expect(out.standardOutput == "mock-ok")
        #expect(out.terminationStatus == 0)
    }
}
