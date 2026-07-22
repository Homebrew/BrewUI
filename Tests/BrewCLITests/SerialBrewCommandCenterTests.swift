//
//  SerialBrewCommandCenterTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import BrewServicesTestSupport
import Foundation
import Testing

private actor PhaseStreamCollector {
    private(set) var phases: [BrewOperationPhase] = []

    func append(_ phase: BrewOperationPhase) {
        phases.append(phase)
    }
}

private actor AllPhaseStreamCollector {
    private(set) var events: [(BrewOperationID, BrewOperationPhase)] = []

    func append(id: BrewOperationID, phase: BrewOperationPhase) {
        events.append((id, phase))
    }
}

private func makeSerialCommandCenterForTests() -> SerialBrewCommandCenter {
    let ctx = BrewCommandExecutionContext(
        commandRunner: MockBrewCommandRunner(responses: [:]),
        locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/fake/brew")),
    )
    return SerialBrewCommandCenter(executionContext: ctx)
}

struct SerialBrewCommandCenterTests {
    private func makeCenter() -> SerialBrewCommandCenter {
        makeSerialCommandCenterForTests()
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
        let id = BrewOperationID(kind: .formula, name: "ok")
        #expect(await center.phase(for: id) == .idle)

        try await center.submit(id: id, command: EmptyMutatingCommand())

        #expect(await center.phase(for: id) == .idle)
    }

    @Test func `records failure with OperationFailure and clears in flight slot`() async throws {
        let center = makeCenter()
        let id = BrewOperationID(kind: .formula, name: "bad")

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
        let id = BrewOperationID(kind: .formula, name: "demo-formula")

        try await center.submit(id: id, command: RunMockedArgvCommand(arguments: argv))

        #expect(await center.phase(for: id) == .idle)
    }

    @Test func `phaseChanges streams initial idle then running and idle on success`() async throws {
        let center = makeCenter()
        let id = BrewOperationID(kind: .formula, name: "stream-success")
        let stream = await center.phaseChanges(for: id)
        let collector = PhaseStreamCollector()
        let collect = Task {
            for await phase in stream {
                await collector.append(phase)
            }
        }
        defer { collect.cancel() }

        try await center.submit(id: id, command: EmptyMutatingCommand())
        try await Task.sleep(for: .milliseconds(80))
        let values = await collector.phases
        #expect(values.count >= 3)
        #expect(values.first == .idle)
        if case .running = values[1] {} else {
            Issue.record("expected running after initial idle")
        }
        #expect(values.last == .idle)
    }

    @Test func `phaseChanges multicast delivers to two subscribers`() async throws {
        let center = makeCenter()
        let id = BrewOperationID(kind: .formula, name: "multi-stream")
        let streamA = await center.phaseChanges(for: id)
        let streamB = await center.phaseChanges(for: id)
        let collectorA = PhaseStreamCollector()
        let collectorB = PhaseStreamCollector()
        let taskA = Task {
            for await phase in streamA {
                await collectorA.append(phase)
            }
        }
        let taskB = Task {
            for await phase in streamB {
                await collectorB.append(phase)
            }
        }
        defer {
            taskA.cancel()
            taskB.cancel()
        }

        try await center.submit(id: id, command: EmptyMutatingCommand())
        try await Task.sleep(for: .milliseconds(80))
        let countA = await collectorA.phases.count
        let countB = await collectorB.phases.count
        #expect(countA >= 3)
        #expect(countB >= 3)
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

struct SerialBrewAllPhaseStreamTests {
    @Test func `allPhaseChanges emits transitions across multiple ids without per id subscriber`() async throws {
        let center = makeSerialCommandCenterForTests()
        let idA = BrewOperationID(kind: .formula, name: "all-phase-a")
        let idB = BrewOperationID(kind: .formula, name: "all-phase-b")
        let stream = await center.allPhaseChanges()
        let collector = AllPhaseStreamCollector()
        let collect = Task {
            for await pair in stream {
                await collector.append(id: pair.0, phase: pair.1)
            }
        }
        defer { collect.cancel() }

        try await center.submit(id: idA, command: EmptyMutatingCommand())
        try await center.submit(id: idB, command: EmptyMutatingCommand())
        try await Task.sleep(for: .milliseconds(80))
        let events = await collector.events
        let eventsForA = events.filter { $0.0 == idA }.map(\.1)
        let eventsForB = events.filter { $0.0 == idB }.map(\.1)
        #expect(eventsForA.count >= 2)
        #expect(eventsForB.count >= 2)
        if case .running = eventsForA[0] {} else {
            Issue.record("expected running as first all-phase event for id A")
        }
        #expect(eventsForA.last == .idle)
        if case .running = eventsForB[0] {} else {
            Issue.record("expected running as first all-phase event for id B")
        }
        #expect(eventsForB.last == .idle)
    }

    @Test func `allPhaseChanges multicast delivers same events to two subscribers`() async throws {
        let center = makeSerialCommandCenterForTests()
        let id = BrewOperationID(kind: .formula, name: "all-phase-multi")
        let streamA = await center.allPhaseChanges()
        let streamB = await center.allPhaseChanges()
        let collectorA = AllPhaseStreamCollector()
        let collectorB = AllPhaseStreamCollector()
        let taskA = Task {
            for await pair in streamA {
                await collectorA.append(id: pair.0, phase: pair.1)
            }
        }
        let taskB = Task {
            for await pair in streamB {
                await collectorB.append(id: pair.0, phase: pair.1)
            }
        }
        defer {
            taskA.cancel()
            taskB.cancel()
        }

        try await center.submit(id: id, command: EmptyMutatingCommand())
        try await Task.sleep(for: .milliseconds(80))
        let eventsA = await collectorA.events
        let eventsB = await collectorB.events
        #expect(eventsA.count == eventsB.count)
        for (left, right) in zip(eventsA, eventsB) {
            #expect(left.0 == right.0)
            #expect(left.1 == right.1)
        }
        #expect(eventsA.count >= 2)
    }

    @Test func `allPhaseChanges removes listener on stream termination`() async throws {
        let center = makeSerialCommandCenterForTests()
        let id = BrewOperationID(kind: .formula, name: "all-phase-cleanup")
        let stream = await center.allPhaseChanges()
        let collector = AllPhaseStreamCollector()
        let collect = Task {
            for await pair in stream {
                await collector.append(id: pair.0, phase: pair.1)
            }
        }
        collect.cancel()
        try await Task.sleep(for: .milliseconds(20))

        try await center.submit(id: id, command: EmptyMutatingCommand())
        try await Task.sleep(for: .milliseconds(80))
        let eventsAfterCancel = await collector.events
        #expect(eventsAfterCancel.isEmpty)

        let stream2 = await center.allPhaseChanges()
        let collector2 = AllPhaseStreamCollector()
        let collect2 = Task {
            for await pair in stream2 {
                await collector2.append(id: pair.0, phase: pair.1)
            }
        }
        defer { collect2.cancel() }

        try await center.submit(id: id, command: EmptyMutatingCommand())
        try await Task.sleep(for: .milliseconds(80))
        let eventsFresh = await collector2.events
        #expect(eventsFresh.count >= 2)
        #expect(eventsFresh.first?.0 == id)
    }
}

// MARK: - Test commands

private struct EmptyMutatingCommand: BrewMutatingCommand {
    var operationKind: BrewOperationKind {
        .upgradeFormula
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        _ = context
    }
}

private struct ThrowingMutatingCommand: BrewMutatingCommand {
    struct TestError: Error {}

    var operationKind: BrewOperationKind {
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

    var operationKind: BrewOperationKind {
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

    var operationKind: BrewOperationKind {
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

    var operationKind: BrewOperationKind {
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

    var operationKind: BrewOperationKind {
        .upgradeFormula
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        let url = try context.brewExecutableURL()
        let out = try await context.commandRunner.run(executableURL: url, arguments: arguments)
        #expect(out.standardOutput == "mock-ok")
        #expect(out.terminationStatus == 0)
    }
}
