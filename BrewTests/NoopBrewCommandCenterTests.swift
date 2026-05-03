//
//  NoopBrewCommandCenterTests.swift
//  BrewTests
//

@testable import Brew
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
        let id = BrewOperationID(rawValue: "formula:broken")

        await #expect(throws: NoopThrowingCommand.TestError.self) {
            try await center.submit(id: id, command: NoopThrowingCommand())
        }
        #expect(await center.phase(for: id) == .idle)
    }
}

// MARK: - Commands

private struct IncrementOnceCommand: BrewMutatingCommand {
    let counter: InvocationCounter

    nonisolated var operationKind: BrewOperationKind { .upgradeFormula }

    func run(in context: BrewCommandExecutionContext) async throws {
        _ = context
        await counter.increment()
    }
}

private struct NoopThrowingCommand: BrewMutatingCommand {
    struct TestError: Error {}

    nonisolated var operationKind: BrewOperationKind { .upgradeCask }

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
