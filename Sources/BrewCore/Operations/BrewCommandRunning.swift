//
//  BrewCommandRunning.swift
//  BrewCore
//

import Foundation

/// Runs `brew` (or any executable) and captures stdout/stderr — mock in tests (`CONVENTIONS.md`).
public protocol BrewCommandRunning: Sendable {
    /// Run to completion, always returning the faithful buffered ``CommandOutput``. ``BrewRunOptions`` control
    /// live streaming and forced colour; runners that don't spawn a real subprocess ignore them.
    func run(executableURL: URL, arguments: [String], options: BrewRunOptions) async throws -> CommandOutput
}

public extension BrewCommandRunning {
    /// Convenience for silent, buffered, colourless runs (background reads like `brew config`, `--json`).
    func run(executableURL: URL, arguments: [String]) async throws -> CommandOutput {
        try await run(executableURL: executableURL, arguments: arguments, options: BrewRunOptions())
    }
}
