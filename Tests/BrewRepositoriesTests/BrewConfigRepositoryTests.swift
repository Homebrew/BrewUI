import BrewCLI
import BrewCore
@testable import BrewRepositories
import BrewServicesTestSupport
import Foundation
import Testing

struct BrewConfigRepositoryTests {
    private static let configStdout = """
    HOMEBREW_VERSION: 4.3.0
    HOMEBREW_PREFIX: /opt/homebrew
    CPU: 8-core
    """

    private func repository(
        runner: any BrewCommandRunning,
        environment: [String: String] = [:],
    ) -> BrewConfigRepository {
        BrewConfigRepository(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew")),
            environment: environment,
        )
    }

    @Test func `loadConfig parses brew config stdout into ordered entries`() async throws {
        let runner = MockBrewCommandRunner(responses: [
            ["config"]: CommandOutput(standardOutput: Self.configStdout, standardError: "", terminationStatus: 0),
        ])

        let snapshot = try await repository(runner: runner).loadConfig()

        #expect(snapshot.entries == [
            BrewConfigEntry(key: "HOMEBREW_VERSION", value: "4.3.0"),
            BrewConfigEntry(key: "HOMEBREW_PREFIX", value: "/opt/homebrew"),
            BrewConfigEntry(key: "CPU", value: "8-core"),
        ])
    }

    @Test func `loadConfig merges only HOMEBREW prefixed environment variables, sorted by name`() async throws {
        let runner = MockBrewCommandRunner(responses: [
            ["config"]: CommandOutput(standardOutput: Self.configStdout, standardError: "", terminationStatus: 0),
        ])
        let environment = [
            "HOMEBREW_NO_ANALYTICS": "1",
            "PATH": "/usr/bin",
            "HOMEBREW_CASK_OPTS": "--no-quarantine",
            "HOME": "/Users/test",
        ]

        let snapshot = try await repository(runner: runner, environment: environment).loadConfig()

        #expect(snapshot.environment == [
            BrewConfigEntry(key: "HOMEBREW_CASK_OPTS", value: "--no-quarantine"),
            BrewConfigEntry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
        ])
    }

    @Test func `loadConfig surfaces a non-zero exit as a command failure`() async {
        let runner = MockBrewCommandRunner(responses: [
            ["config"]: CommandOutput(standardOutput: "", standardError: "boom", terminationStatus: 1),
        ])

        await #expect(throws: BrewCommandError.failed(exitCode: 1, stderr: "boom")) {
            try await repository(runner: runner).loadConfig()
        }
    }

    @Test func `loadConfig surfaces a missing brew executable`() async {
        let runner = MockBrewCommandRunner(responses: [:])
        let repository = BrewConfigRepository(
            commandRunner: runner,
            locator: MissingBrewExecutableLocator(),
        )

        await #expect(throws: BrewLookupError.executableNotFound) {
            try await repository.loadConfig()
        }
    }
}
