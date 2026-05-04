//
//  PackageUpgradeCommandTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct PackageUpgradeCommandTests {
    @Test func `operation id from row matches InstalledPackageRow id`() {
        let row = InstalledPackageRow(name: "wget", kind: .formula, description: "", installedVersion: "v1")
        #expect(BrewOperationID(row: row).rawValue == row.id)
    }

    @Test func `formula run invokes brew upgrade name`() async throws {
        let runner = CapturingCommandRunner()
        let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )
        let row = InstalledPackageRow(name: "git", kind: .formula, description: "", installedVersion: "v2")
        try await PackageUpgradeCommand(row: row).run(in: ctx)

        #expect(await runner.lastExecutable == brewURL)
        #expect(await runner.lastArguments == ["upgrade", "git"])
    }

    @Test func `cask run invokes brew upgrade cask name`() async throws {
        let runner = CapturingCommandRunner()
        let brewURL = URL(fileURLWithPath: "/usr/local/bin/brew")
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )
        let row = InstalledPackageRow(name: "Slack", kind: .cask, description: "", installedVersion: "v1")
        try await PackageUpgradeCommand(row: row).run(in: ctx)

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
        let row = InstalledPackageRow(name: "x", kind: .formula, description: "", installedVersion: "v1")
        await #expect(throws: BrewCommandError.self) {
            try await PackageUpgradeCommand(row: row).run(in: ctx)
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
