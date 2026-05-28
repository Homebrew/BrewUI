//
//  BrewCommandExecutionContext+Preview.swift
//  Brew
//

import BrewCore
import Foundation

public extension BrewCommandExecutionContext {
    /// Runner returns empty success without touching disk; locator yields a dummy `brew` URL for callers that resolve it.
    nonisolated static func noopForTestingAndPreviews() -> BrewCommandExecutionContext {
        BrewCommandExecutionContext(
            commandRunner: ImmediateSuccessCommandRunner(),
            locator: BrewExecutableLocator(overrideURL: URL(fileURLWithPath: "/opt/homebrew/bin/brew")),
        )
    }
}

private nonisolated struct ImmediateSuccessCommandRunner: BrewCommandRunning {
    func run(executableURL _: URL, arguments _: [String]) async throws -> CommandOutput {
        CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }
}
