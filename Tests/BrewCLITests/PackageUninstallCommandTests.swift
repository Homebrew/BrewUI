//
//  PackageUninstallCommandTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import BrewCoreTestSupport
import BrewServicesTestSupport
import Foundation
import Testing

struct PackageUninstallCommandTests {
    @Test func `formula run invokes brew uninstall formula name`() async throws {
        let runner = CapturingUninstallCommandRunner()
        let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )
        let package = InstalledBrewPackage.fixture(name: "git", kind: .formula)
        try await PackageUninstallCommand(package: package).run(in: ctx)

        #expect(await runner.lastExecutable == brewURL)
        #expect(await runner.lastArguments == ["uninstall", "--formula", "git"])
    }

    @Test func `cask run invokes brew uninstall cask name`() async throws {
        let runner = CapturingUninstallCommandRunner()
        let brewURL = URL(fileURLWithPath: "/usr/local/bin/brew")
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )
        let package = InstalledBrewPackage.fixture(name: "Slack", kind: .cask)
        try await PackageUninstallCommand(package: package).run(in: ctx)

        #expect(await runner.lastArguments == ["uninstall", "--cask", "Slack"])
    }

    @Test func `nonzero exit throws BrewCommandError`() async {
        let runner = CapturingUninstallCommandRunner()
        await runner.setOutput(
            CommandOutput(standardOutput: "", standardError: "blocked", terminationStatus: 1),
        )
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew")),
        )
        let package = InstalledBrewPackage.fixture(name: "x", kind: .formula)
        await #expect(throws: BrewCommandError.self) {
            try await PackageUninstallCommand(package: package).run(in: ctx)
        }
    }

    @Test func `kind and name initializer matches uninstall argv`() async throws {
        let runner = CapturingUninstallCommandRunner()
        let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        let ctx = BrewCommandExecutionContext(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )

        try await PackageUninstallCommand(kind: .formula, name: "wget").run(in: ctx)
        #expect(await runner.lastExecutable == brewURL)
        #expect(await runner.lastArguments == ["uninstall", "--formula", "wget"])
    }
}

private actor CapturingUninstallCommandRunner: BrewCommandRunning {
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
