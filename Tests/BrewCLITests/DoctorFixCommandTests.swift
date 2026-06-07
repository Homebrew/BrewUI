//
//  DoctorFixCommandTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import Foundation
import Testing

struct DoctorFixCommandTests {
    @Test func `run invokes brew with the supplied argument vector`() async throws {
        let runner = CapturingCommandRunner()
        let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )

        try await DoctorFixCommand(arguments: ["link", "openssl@3"]).run(in: ctx)

        #expect(await runner.lastExecutable == brewURL)
        #expect(await runner.lastArguments == ["link", "openssl@3"])
    }

    @Test func `operation kind is doctorFix`() {
        #expect(DoctorFixCommand(arguments: ["cleanup"]).operationKind == .doctorFix)
    }

    @Test func `factory vends a doctorFix command`() {
        let command = LiveBrewMutatingCommandFactory().doctorFixCommand(arguments: ["cleanup"])
        #expect(command.operationKind == .doctorFix)
    }

    @Test func `nonzero exit throws BrewCommandError`() async {
        let runner = CapturingCommandRunner()
        await runner.setOutput(
            CommandOutput(standardOutput: "", standardError: "could not link", terminationStatus: 1),
        )
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew")),
        )

        await #expect(throws: BrewCommandError.self) {
            try await DoctorFixCommand(arguments: ["link", "broken"]).run(in: ctx)
        }
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
