//
//  BrewCommandRunning.swift
//  BrewCore
//

import Foundation

/// Runs `brew` (or any executable) and captures stdout/stderr — mock in tests (`CONVENTIONS.md`).
public protocol BrewCommandRunning: Sendable {
    func run(executableURL: URL, arguments: [String]) async throws -> CommandOutput
}
