//
//  NoopBrewCommandCenterTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import Foundation
import Testing

private let sampleCommand = BrewCommand(operationKind: .upgradeFormula, arguments: ["x"])

private func noopCenter(runner: any BrewCommandRunning) -> NoopBrewCommandCenter {
    NoopBrewCommandCenter(executionContext: BrewCommandExecutionContext(
        commandRunner: runner,
        locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/fake/brew")),
    ))
}

struct NoopBrewCommandCenterTests {
    @Test func `phase stays idle while no work is submitted`() async {
        let center = NoopBrewCommandCenter.forTesting()
        let id = BrewOperationID(kind: .formula, name: "hello")

        #expect(await center.phase(for: id) == .idle)
    }

    @Test func `run executes the command without tracking phase`() async throws {
        let counter = InvocationCounter()
        let center = noopCenter(runner: CountingRunner(counter: counter))
        let id = BrewOperationID(kind: .cask, name: "slack")

        try await center.perform(sampleCommand, id: id)

        #expect(await counter.value == 1)
        #expect(await center.phase(for: id) == .idle)
    }

    @Test func `run propagates thrown errors`() async {
        let center = noopCenter(runner: ThrowingRunner())
        let id = BrewOperationID(kind: .formula, name: "broken")

        await #expect(throws: ThrowingRunner.TestError.self) {
            try await center.perform(sampleCommand, id: id)
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

// MARK: - Test doubles

private struct CountingRunner: BrewCommandRunning {
    let counter: InvocationCounter

    func run(executableURL _: URL, arguments _: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        await counter.increment()
        return CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }
}

private struct ThrowingRunner: BrewCommandRunning {
    struct TestError: Error {}

    func run(executableURL _: URL, arguments _: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        throw TestError()
    }
}

private actor InvocationCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
