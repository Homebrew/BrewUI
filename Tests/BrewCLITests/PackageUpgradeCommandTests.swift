//
//  PackageUpgradeCommandTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import BrewCoreTestSupport
import BrewServicesTestSupport
import Foundation
import Testing

struct PackageUpgradeCommandTests {
    @Test func `operation id from package matches package id`() {
        let package = InstalledBrewPackage.fixture(name: "wget", kind: .formula)
        #expect(BrewOperationID(package: package).packageID == .formula(name: "wget"))
    }

    @Test func `formula run invokes brew upgrade name`() async throws {
        let runner = CapturingCommandRunner()
        let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )
        let package = InstalledBrewPackage.fixture(name: "git", kind: .formula)
        try await PackageUpgradeCommand(package: package).run(in: ctx)

        #expect(await runner.lastExecutable == brewURL)
        #expect(await runner.lastArguments == ["upgrade", "--formula", "git"])
    }

    @Test func `cask run invokes brew upgrade cask name`() async throws {
        let runner = CapturingCommandRunner()
        let brewURL = URL(fileURLWithPath: "/usr/local/bin/brew")
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )
        let package = InstalledBrewPackage.fixture(name: "Slack", kind: .cask)
        try await PackageUpgradeCommand(package: package).run(in: ctx)

        #expect(await runner.lastArguments == ["upgrade", "--cask", "Slack"])
    }

    @Test func `nonzero exit throws BrewCommandError`() async {
        let runner = CapturingCommandRunner()
        await runner.setOutput(
            CommandOutput(standardOutput: "", standardError: "blocked", terminationStatus: 1),
        )
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew")),
        )
        let package = InstalledBrewPackage.fixture(name: "x", kind: .formula)
        await #expect(throws: BrewCommandError.self) {
            try await PackageUpgradeCommand(package: package).run(in: ctx)
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
