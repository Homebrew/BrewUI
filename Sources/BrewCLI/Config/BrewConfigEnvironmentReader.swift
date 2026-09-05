//
//  BrewConfigEnvironmentReader.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Asks `brew config`, which prints `HOMEBREW_NO_INSTALL_FROM_API: set` only when it is set.
/// Probed once: changing it means editing a shell profile, which needs a relaunch anyway.
public actor BrewConfigEnvironmentReader: HomebrewEnvironmentReading {
    private static let noInstallFromAPIKey = "HOMEBREW_NO_INSTALL_FROM_API"

    private let commandRunner: any BrewCommandRunning
    private let locator: any BrewExecutableLocating
    private var probed: Bool?

    public init(commandRunner: any BrewCommandRunning, locator: any BrewExecutableLocating) {
        self.commandRunner = commandRunner
        self.locator = locator
    }

    public init(executionContext: BrewCommandExecutionContext) {
        self.init(commandRunner: executionContext.commandRunner, locator: executionContext.locator)
    }

    public func isInstallFromAPIDisabled() async -> Bool {
        if let probed {
            return probed
        }
        let result = await probe()
        probed = result
        return result
    }

    /// Falls back to the API path; the caller's own brew invocation surfaces the real problem.
    private func probe() async -> Bool {
        guard let brew = try? locator.findBrewExecutable(),
              let output = try? await commandRunner.run(executableURL: brew, arguments: ["config"]),
              output.terminationStatus == 0
        else {
            return false
        }
        return BrewConfigParser.parse(output.standardOutput).entries
            .contains { $0.key == Self.noInstallFromAPIKey }
    }
}
