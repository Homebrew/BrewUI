//
//  BulkUpgradeCommandTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import BrewServicesTestSupport
import Foundation
import Testing

struct BulkUpgradeCommandTests {
    @Test func `run invokes brew upgrade with no arguments`() async throws {
        let runner = CapturingCommandRunner()
        let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )

        try await BulkUpgradeCommand().run(in: ctx)

        #expect(await runner.lastExecutable == brewURL)
        #expect(await runner.lastArguments == ["upgrade"])
    }

    @Test func `nonzero exit throws BrewCommandError with stderr`() async {
        let runner = CapturingCommandRunner()
        await runner.setOutput(
            CommandOutput(standardOutput: "", standardError: "conflict", terminationStatus: 1),
        )
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew")),
        )

        await #expect(throws: BrewCommandError.self) {
            try await BulkUpgradeCommand().run(in: ctx)
        }
    }

    @Test func `operationKind is upgradeAll`() {
        #expect(BulkUpgradeCommand().operationKind == .upgradeAll)
    }
}

// MARK: - Test doubles

private actor CapturingCommandRunner: BrewCommandRunning {
    private(set) var lastExecutable: URL?
    private(set) var lastArguments: [String]?
    private var output = CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)

    func setOutput(_ output: CommandOutput) {
        self.output = output
    }

    func run(executableURL: URL, arguments: [String]) async throws -> CommandOutput {
        lastExecutable = executableURL
        lastArguments = arguments
        return output
    }
}
