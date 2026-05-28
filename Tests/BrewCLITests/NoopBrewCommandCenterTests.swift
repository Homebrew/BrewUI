//
//  NoopBrewCommandCenterTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import BrewCoreTestSupport
import BrewServicesTestSupport
import Foundation
import Testing

struct NoopBrewCommandCenterTests {
    @Test func `phase and activity stay empty while idle`() async {
        let center = NoopBrewCommandCenter.forTesting()
        let id = BrewOperationID(kind: .formula, name: "hello")

        #expect(await center.phase(for: id) == .idle)
        #expect(await center.phaseByID().isEmpty)
        #expect(await !center.isActive(id: id))
    }

    @Test func `submit runs command without tracking phase`() async throws {
        let center = NoopBrewCommandCenter.forTesting()
        let id = BrewOperationID(kind: .cask, name: "slack")
        let counter = InvocationCounter()

        try await center.submit(id: id, command: IncrementOnceCommand(counter: counter))

        #expect(await counter.value == 1)
        #expect(await center.phase(for: id) == .idle)
        #expect(await center.phaseByID().isEmpty)
        #expect(await !center.isActive(id: id))
    }

    @Test func `submit propagates thrown errors`() async {
        let center = NoopBrewCommandCenter.forTesting()
        let id = BrewOperationID(kind: .formula, name: "broken")

        await #expect(throws: NoopThrowingCommand.TestError.self) {
            try await center.submit(id: id, command: NoopThrowingCommand())
        }
        #expect(await center.phase(for: id) == .idle)
    }

    @Test func `allPhaseChanges finishes immediately with no events`() async {
        let center = NoopBrewCommandCenter.forTesting()
        let stream = await center.allPhaseChanges()
        var eventCount = 0
        for await _ in stream {
            eventCount += 1
        }
        #expect(eventCount == 0)
    }
}

// MARK: - Commands

private struct IncrementOnceCommand: BrewMutatingCommand {
    let counter: InvocationCounter

    nonisolated var operationKind: BrewOperationKind {
        .upgradeFormula
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        _ = context
        await counter.increment()
    }
}

private struct NoopThrowingCommand: BrewMutatingCommand {
    struct TestError: Error {}

    nonisolated var operationKind: BrewOperationKind {
        .upgradeCask
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        _ = context
        throw TestError()
    }
}

private actor InvocationCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
