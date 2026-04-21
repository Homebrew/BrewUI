//
//  BrewCommandService.swift
//  Brew
//

import Foundation

/// Subprocess runner for Homebrew CLI (`ARCHITECTURE.md` — Command execution).
struct BrewCommandService: BrewCommandRunning {
    func run(executableURL: URL, arguments: [String]) async throws -> CommandOutput {
        try await Task.detached {
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            process.standardInput = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                throw BrewCommandError.launchFailed(underlying: String(describing: error))
            }
            process.waitUntilExit()

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let stdout = String(bytes: outData, encoding: .utf8) ?? ""
            let stderr = String(bytes: errData, encoding: .utf8) ?? ""
            return CommandOutput(
                standardOutput: stdout,
                standardError: stderr,
                terminationStatus: process.terminationStatus,
            )
        }.value
    }
}
