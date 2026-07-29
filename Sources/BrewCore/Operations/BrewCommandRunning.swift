//
//  BrewCommandRunning.swift
//  BrewCore
//

import Foundation

/// Runs `brew` (or any executable) and captures stdout/stderr — mock in tests (`CONVENTIONS.md`).
public protocol BrewCommandRunning: Sendable {
    /// Run to completion and return the buffered, colourless output.
    func run(executableURL: URL, arguments: [String]) async throws -> CommandOutput

    /// Run while streaming each output line to `console` as it arrives, and (when `console` is non-nil)
    /// forcing Homebrew to emit ANSI colour. The returned ``CommandOutput`` is still the faithful
    /// buffered capture. Runners that don't stream (mocks, read-only doubles) inherit the default below,
    /// which ignores `console` — only the production subprocess runners override it.
    func run(executableURL: URL, arguments: [String], console: ConsoleOutputStream?) async throws -> CommandOutput
}

public extension BrewCommandRunning {
    func run(
        executableURL: URL,
        arguments: [String],
        console _: ConsoleOutputStream?,
    ) async throws -> CommandOutput {
        try await run(executableURL: executableURL, arguments: arguments)
    }
}
