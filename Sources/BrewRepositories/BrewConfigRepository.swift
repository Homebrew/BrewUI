//
//  BrewConfigRepository.swift
//  BrewRepositories
//

import BrewCLI
import BrewCore
import BrewRepositoryInterfaces
import Foundation

/// Live `ConfigRepository`: runs `brew config`, parses it, and merges the effective `HOMEBREW_*`
/// process environment. One-shot and stateless, so a plain `struct` (cf. `BrewDiscoverPackagesRepository`).
public struct BrewConfigRepository: ConfigRepository {
    private let commandRunner: any BrewCommandRunning
    private let locator: any BrewExecutableLocating
    private let environment: [String: String]

    public init(
        commandRunner: any BrewCommandRunning,
        locator: any BrewExecutableLocating,
        environment: [String: String] = ProcessInfo.processInfo.environment,
    ) {
        self.commandRunner = commandRunner
        self.locator = locator
        self.environment = environment
    }

    /// Production wiring: real subprocess + default `brew` lookup + the live process environment.
    public static func live() -> BrewConfigRepository {
        BrewConfigRepository(
            commandRunner: BrewCommandService(),
            locator: BrewExecutableLocator(),
        )
    }

    public func loadConfig() async throws -> BrewConfigSnapshot {
        let brew = try locator.findBrewExecutable()
        let output = try await commandRunner.run(executableURL: brew, arguments: ["config"])
        guard output.terminationStatus == 0 else {
            throw BrewCommandError.failed(exitCode: output.terminationStatus, stderr: output.standardError)
        }
        let parsed = BrewConfigParser.parse(output.standardOutput)
        return BrewConfigSnapshot(
            entries: parsed.entries,
            environment: homebrewEnvironmentEntries(),
        )
    }

    private func homebrewEnvironmentEntries() -> [BrewConfigEntry] {
        environment
            .filter { $0.key.hasPrefix("HOMEBREW_") }
            .sorted { $0.key < $1.key }
            .map { BrewConfigEntry(key: $0.key, value: $0.value) }
    }
}
