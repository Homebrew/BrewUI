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

            // Drain pipes concurrently while the subprocess runs.
            // Large outputs (for example `brew info --installed --json=v2`) can deadlock
            // if we wait for exit before reading from stdout/stderr.
            let outReadTask = Task.detached {
                outPipe.fileHandleForReading.readDataToEndOfFile()
            }
            let errReadTask = Task.detached {
                errPipe.fileHandleForReading.readDataToEndOfFile()
            }

            process.waitUntilExit()

            let outData = await outReadTask.value
            let errData = await errReadTask.value
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
