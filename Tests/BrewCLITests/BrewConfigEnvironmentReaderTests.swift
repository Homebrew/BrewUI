//
//  BrewConfigEnvironmentReaderTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewServicesTestSupport
import Foundation
import Testing

struct BrewConfigEnvironmentReaderTests {
    private static let brewURL = URL(fileURLWithPath: "/fake/brew")

    /// `brew config` prints the row only when the variable is set, so presence is the signal.
    private static func configOutput(includingNoInstallFromAPI: Bool) -> String {
        var lines = [
            "HOMEBREW_VERSION: 6.0.20",
            "HOMEBREW_PREFIX: /opt/homebrew",
        ]
        if includingNoInstallFromAPI {
            lines.append("HOMEBREW_NO_INSTALL_FROM_API: set")
        }
        lines.append("macOS: 26.5-arm64")
        return lines.joined(separator: "\n")
    }

    private static func reader(
        behaviors: [[String]: MockBrewCommandRunnerBehavior],
    ) -> BrewConfigEnvironmentReader {
        BrewConfigEnvironmentReader(
            commandRunner: MockBrewCommandRunner(behaviors: behaviors),
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )
    }

    @Test func `reports the API disabled when brew config lists the variable`() async {
        let reader = Self.reader(behaviors: [
            ["config"]: .output(CommandOutput(
                standardOutput: Self.configOutput(includingNoInstallFromAPI: true),
                standardError: "",
                terminationStatus: 0,
            )),
        ])

        #expect(await reader.isInstallFromAPIDisabled())
    }

    @Test func `reports the API in use when brew config omits the variable`() async {
        let reader = Self.reader(behaviors: [
            ["config"]: .output(CommandOutput(
                standardOutput: Self.configOutput(includingNoInstallFromAPI: false),
                standardError: "",
                terminationStatus: 0,
            )),
        ])

        #expect(await reader.isInstallFromAPIDisabled() == false)
    }

    @Test func `falls back to the API path when brew config cannot run`() async {
        let reader = Self.reader(behaviors: [
            ["config"]: .throw(BrewCommandError.launchFailed(underlying: "could not spawn brew")),
        ])

        #expect(await reader.isInstallFromAPIDisabled() == false)
    }

    @Test func `falls back to the API path when brew config exits non zero`() async {
        let reader = Self.reader(behaviors: [
            ["config"]: .output(CommandOutput(
                standardOutput: Self.configOutput(includingNoInstallFromAPI: true),
                standardError: "boom",
                terminationStatus: 1,
            )),
        ])

        // Non-zero output is not trustworthy, even when it happens to contain the row.
        #expect(await reader.isInstallFromAPIDisabled() == false)
    }

    @Test func `falls back to the API path when brew cannot be located`() async {
        let reader = BrewConfigEnvironmentReader(
            commandRunner: MockBrewCommandRunner(behaviors: [:]),
            locator: MissingBrewExecutableLocator(),
        )

        #expect(await reader.isInstallFromAPIDisabled() == false)
    }

    @Test func `the answer is probed once and reused`() async {
        let runner = CountingConfigRunner(
            standardOutput: Self.configOutput(includingNoInstallFromAPI: true),
        )
        let reader = BrewConfigEnvironmentReader(
            commandRunner: runner,
            locator: BrewExecutableLocator(overrideURL: Self.brewURL),
        )

        #expect(await reader.isInstallFromAPIDisabled())
        #expect(await reader.isInstallFromAPIDisabled())

        #expect(await runner.callCount == 1)
    }
}

private actor CountingConfigRunner: BrewCommandRunning {
    private let standardOutput: String
    private(set) var callCount = 0

    init(standardOutput: String) {
        self.standardOutput = standardOutput
    }

    func run(executableURL _: URL, arguments _: [String], options _: BrewRunOptions) async throws -> CommandOutput {
        callCount += 1
        return CommandOutput(standardOutput: standardOutput, standardError: "", terminationStatus: 0)
    }
}
