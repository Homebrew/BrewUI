//
//  PackageInstallCommandTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import Foundation
import Testing

struct PackageInstallCommandTests {
    @Test func `formula run invokes brew install name`() async throws {
        let runner = CapturingInstallRunner()
        let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )
        try await PackageInstallCommand(kind: .formula, name: "git").run(in: ctx)

        #expect(await runner.lastExecutable == brewURL)
        #expect(await runner.lastArguments == ["install", "--formula", "git"])
    }

    @Test func `cask run invokes brew install cask name`() async throws {
        let runner = CapturingInstallRunner()
        let brewURL = URL(fileURLWithPath: "/usr/local/bin/brew")
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )
        try await PackageInstallCommand(kind: .cask, name: "docker").run(in: ctx)

        #expect(await runner.lastArguments == ["install", "--cask", "docker"])
    }

    @Test func `operation kind reflects package kind`() {
        #expect(PackageInstallCommand(kind: .formula, name: "git").operationKind == .installFormula)
        #expect(PackageInstallCommand(kind: .cask, name: "docker").operationKind == .installCask)
    }

    @Test func `nonzero exit throws BrewCommandError`() async {
        let runner = CapturingInstallRunner()
        await runner.setOutput(
            CommandOutput(standardOutput: "", standardError: "blocked", terminationStatus: 1),
        )
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew")),
        )
        await #expect(throws: BrewCommandError.self) {
            try await PackageInstallCommand(kind: .formula, name: "x").run(in: ctx)
        }
    }
}

// MARK: - Test doubles

private actor CapturingInstallRunner: BrewCommandRunning {
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
