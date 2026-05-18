//
//  BrewCommandService.swift
//  Brew
//

import Foundation

/// Subprocess runner for Homebrew CLI (`ARCHITECTURE.md` — Command execution).
struct BrewCommandService: BrewCommandRunning {
    nonisolated init() {}

    nonisolated func run(executableURL: URL, arguments: [String]) async throws -> CommandOutput {
        try Task.checkCancellation()

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

        let processController = ProcessController(process)
        return try await withTaskCancellationHandler(operation: {
            // Drain pipes concurrently while the subprocess runs.
            // Large outputs (for example `brew info --installed --json=v2`) can deadlock
            // if we wait for exit before reading from stdout/stderr.
            async let outRead = Self.readAllData(from: outPipe.fileHandleForReading)
            async let errRead = Self.readAllData(from: errPipe.fileHandleForReading)

            let terminationStatus = await Self.waitForExit(process)
            let outData = await outRead
            let errData = await errRead
            try Task.checkCancellation()

            let stdout = String(bytes: outData, encoding: .utf8) ?? ""
            let stderr = String(bytes: errData, encoding: .utf8) ?? ""
            return CommandOutput(
                standardOutput: stdout,
                standardError: stderr,
                terminationStatus: terminationStatus,
            )
        }, onCancel: {
            processController.terminateIfRunning()
        })
    }

    private nonisolated static func readAllData(from handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            // `readDataToEndOfFile` blocks; run on a GCD worker thread.
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: handle.readDataToEndOfFile())
            }
        }
    }

    private nonisolated static func waitForExit(_ process: Process) async -> Int32 {
        await withCheckedContinuation { continuation in
            // `waitUntilExit` blocks; run on a GCD worker thread.
            DispatchQueue.global(qos: .utility).async {
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus)
            }
        }
    }
}

private final class ProcessController: @unchecked Sendable {
    private let lock = NSLock()
    private let process: Process

    nonisolated init(_ process: Process) {
        self.process = process
    }

    nonisolated func terminateIfRunning() {
        lock.lock()
        defer { lock.unlock() }
        if process.isRunning {
            process.terminate()
        }
    }
}
