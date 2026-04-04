//
//  BrewCommandRunning.swift
//  Brew
//

import Foundation

/// Runs `brew` (or any executable) and captures stdout/stderr — mock in tests (`CONVENTIONS.md`).
protocol BrewCommandRunning: Sendable {
    func run(executableURL: URL, arguments: [String]) async throws -> CommandOutput
}
