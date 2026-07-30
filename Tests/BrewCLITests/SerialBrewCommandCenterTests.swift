//
//  SerialBrewCommandCenterTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import BrewCoreTestSupport
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

private let successOutput = CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)

/// A plain command value used wherever the test only cares about scheduling, not argv.
private let noopCommand = BrewCommand(operationKind: .upgradeFormula, arguments: ["noop"])

private func makeCenter(runner: any BrewCommandRunning) -> SerialBrewCommandCenter {
    let ctx = BrewCommandExecutionContext(
        commandRunner: runner,
        locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/fake/brew")),
    )
    return SerialBrewCommandCenter(executionContext: ctx)
}

private func makeSucceedingCenter() -> SerialBrewCommandCenter {
    makeCenter(runner: ClosureRunner { _ in successOutput })
}

struct SerialBrewCommandCenterTests {
    @Test func `serializes operations so second runs after first`() async throws {
        let collector = OrderCollector()
        // Commands are inert data now, so the ordering/sleep behaviour lives in the runner, keyed by argv.
        let center = makeCenter(runner: ClosureRunner { argv in
            if argv == ["a"] {
                await collector.append("a-start")
                try await Task.sleep(for: .milliseconds(20))
                await collector.append("a-end")
            } else {
                await collector.append("b")
            }
            return successOutput
        })
        let idA = BrewOperationID(kind: .formula, name: "a")
        let idB = BrewOperationID(kind: .formula, name: "b")

        try await center.runExpectingSuccess(BrewCommand(operationKind: .upgradeFormula, arguments: ["a"]), id: idA)
        try await center.runExpectingSuccess(BrewCommand(operationKind: .upgradeFormula, arguments: ["b"]), id: idB)

        let order = await collector.snapshot()
        #expect(order == ["a-start", "a-end", "b"])
    }

    @Test func `duplicate id coalesces to a single command body`() async throws {
        let counter = InvocationCounter()
        let center = makeCenter(runner: ClosureRunner { _ in
            await counter.increment()
            try await Task.sleep(for: .milliseconds(30))
            return successOutput
        })
        let id = BrewOperationID(kind: .formula, name: "git")

        let first = Task { try await center.runExpectingSuccess(noopCommand, id: id) }
        try await Task.sleep(for: .milliseconds(5))
        let second = Task { try await center.runExpectingSuccess(noopCommand, id: id) }

        try await first.value
        try await second.value
        #expect(await counter.value == 1)
    }

    @Test func `clears running phase on success`() async throws {
        let center = makeSucceedingCenter()
        let id = BrewOperationID(kind: .formula, name: "ok")
        #expect(await center.phase(for: id) == .idle)

        try await center.runExpectingSuccess(noopCommand, id: id)

        #expect(await center.phase(for: id) == .idle)
        #expect(await !center.isActive(id: id))
    }

    @Test func `records failure with OperationFailure and clears in flight slot`() async throws {
        // A non-zero exit is a failure in `.display` mode (runExpectingSuccess).
        let center = makeCenter(runner: ClosureRunner { _ in
            CommandOutput(standardOutput: "", standardError: "boom", terminationStatus: 1)
        })
        let id = BrewOperationID(kind: .formula, name: "bad")

        do {
            try await center.runExpectingSuccess(noopCommand, id: id)
            Issue.record("expected run to throw")
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

    @Test func `capture mode returns output and does not treat a non-zero exit as failure`() async throws {
        // `brew doctor` exits non-zero on warnings — capture mode surfaces the output, not a failure.
        let center = makeCenter(runner: ClosureRunner { _ in
            CommandOutput(standardOutput: "warnings", standardError: "", terminationStatus: 1)
        })
        let id = BrewOperationID(kind: .formula, name: "doctor")

        let output = try await center.run(BrewCommand(operationKind: .doctorRead, arguments: ["doctor"]), id: id)

        #expect(output.standardOutput == "warnings")
        #expect(output.terminationStatus == 1)
        #expect(await center.phase(for: id) == .idle)
    }

    @Test func `phaseByID exposes tracked entries`() async throws {
        let center = makeCenter(runner: ClosureRunner { _ in
            CommandOutput(standardOutput: "", standardError: "boom", terminationStatus: 1)
        })
        let id = BrewOperationID(kind: .formula, name: "snapshot")
        #expect(await center.phaseByID().isEmpty)

        do {
            try await center.runExpectingSuccess(noopCommand, id: id)
        } catch {
            _ = error
        }

        let map = await center.phaseByID()
        #expect(map[id] != nil)
        #expect(await center.phase(for: id) == map[id])
    }

    @Test func `runs the injected mock runner not real brew`() async throws {
        let argv = ["upgrade", "demo-formula"]
        let runner = MockBrewCommandRunner(responses: [
            argv: CommandOutput(standardOutput: "mock-ok", standardError: "", terminationStatus: 0),
        ])
        let center = makeCenter(runner: runner)
        let id = BrewOperationID(kind: .formula, name: "demo-formula")

        let output = try await center.run(BrewCommand(operationKind: .upgradeFormula, arguments: argv), id: id)

        #expect(output.standardOutput == "mock-ok")
        #expect(await center.phase(for: id) == .idle)
    }

    @Test func `phaseChanges streams initial idle then running and idle on success`() async throws {
        let center = makeSucceedingCenter()
        let id = BrewOperationID(kind: .formula, name: "stream-success")
        let stream = await center.phaseChanges(for: id)
        let collector = PhaseStreamCollector()
        let collect = Task {
            for await phase in stream {
                await collector.append(phase)
            }
        }
        defer { collect.cancel() }

        try await center.runExpectingSuccess(noopCommand, id: id)
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
        let center = makeSucceedingCenter()
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

        try await center.runExpectingSuccess(noopCommand, id: id)
        try await Task.sleep(for: .milliseconds(80))
        let countA = await collectorA.phases.count
        let countB = await collectorB.phases.count
        #expect(countA >= 3)
        #expect(countB >= 3)
    }

    @Test func `recording wrapper logs each submit while duplicate id coalesces body`() async throws {
        let counter = InvocationCounter()
        let ctx = BrewCommandExecutionContext(
            commandRunner: ClosureRunner { _ in
                await counter.increment()
                try await Task.sleep(for: .milliseconds(30))
                return successOutput
            },
            locator: BrewExecutableLocator(overrideURL: InstalledPackagesTestSupport.fakeBrewExecutableURL),
        )
        let center = RecordingSerialBrewCommandCenter(executionContext: ctx)
        let id = BrewOperationID(kind: .formula, name: "git")

        let first = Task { try await center.runExpectingSuccess(noopCommand, id: id) }
        try await Task.sleep(for: .milliseconds(5))
        let second = Task { try await center.runExpectingSuccess(noopCommand, id: id) }

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
        let center = makeSucceedingCenter()
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

        try await center.runExpectingSuccess(noopCommand, id: idA)
        try await center.runExpectingSuccess(noopCommand, id: idB)
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
        let center = makeSucceedingCenter()
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

        try await center.runExpectingSuccess(noopCommand, id: id)
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
        let center = makeSucceedingCenter()
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

        try await center.runExpectingSuccess(noopCommand, id: id)
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

        try await center.runExpectingSuccess(noopCommand, id: id)
        try await Task.sleep(for: .milliseconds(80))
        let eventsFresh = await collector2.events
        #expect(eventsFresh.count >= 2)
        #expect(eventsFresh.first?.0 == id)
    }
}

// MARK: - Test doubles

/// Runner whose behaviour is a closure of the argv. Commands are inert data now, so tests drive
/// sleep/throw/counting/ordering from the runner instead of a custom command type.
private struct ClosureRunner: BrewCommandRunning {
    let body: @Sendable ([String]) async throws -> CommandOutput

    func run(executableURL _: URL, arguments: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        try await body(arguments)
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

private actor InvocationCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
