//
//  BrewCommandService.swift
//  Brew
//

import BrewCore
import Foundation

/// Subprocess runner for Homebrew CLI (`ARCHITECTURE.md` — Command execution).
public struct BrewCommandService: BrewCommandRunning {
    public nonisolated init() {}

    public nonisolated func run(executableURL: URL, arguments: [String]) async throws -> CommandOutput {
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

        // Reading the sink once here (rather than per chunk) snapshots the value while the TaskLocal scope is active.
        // When no console is observing, `sink` is nil and the drain skips the line-splitting work.
        let sink = BrewCommandOutputContext.sink

        let processController = ProcessController(process)
        return try await withTaskCancellationHandler(operation: {
            // Drain pipes concurrently while the subprocess runs.
            // Large outputs (for example `brew info --installed --json=v2`) can deadlock
            // if we wait for exit before reading from stdout/stderr.
            async let outRead = Self.drainPipe(
                handle: outPipe.fileHandleForReading,
                stream: .stdout,
                sink: sink,
            )
            async let errRead = Self.drainPipe(
                handle: errPipe.fileHandleForReading,
                stream: .stderr,
                sink: sink,
            )

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

    /// Drains a subprocess pipe to EOF, returning the raw bytes verbatim for ``CommandOutput``.
    /// When `sink` is non-nil, also emits each `\n`-terminated line through it as bytes arrive — the trailing
    /// partial line (no terminating newline) is flushed on EOF if non-empty. Lines whose bytes aren't valid UTF-8
    /// are dropped from the stream (they remain in the verbatim byte return).
    private nonisolated static func drainPipe(
        handle: FileHandle,
        stream: BrewCommandOutputLine.Stream,
        sink: (@Sendable (BrewCommandOutputLine) -> Void)?,
    ) async -> Data {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
            // `availableData` blocks; run on a GCD worker thread (matches `readAllData` behavior).
            DispatchQueue.global(qos: .utility).async {
                var fullOutput = Data()
                var lineBuffer = Data()
                while true {
                    let chunk = handle.availableData
                    if chunk.isEmpty {
                        if let sink, !lineBuffer.isEmpty,
                           let final = String(data: lineBuffer, encoding: .utf8)
                        {
                            sink(BrewCommandOutputLine(stream: stream, text: final))
                        }
                        break
                    }
                    fullOutput.append(chunk)
                    if let sink {
                        lineBuffer.append(chunk)
                        while let newlineIndex = lineBuffer.firstIndex(of: 0x0A) {
                            let offset = lineBuffer.distance(from: lineBuffer.startIndex, to: newlineIndex)
                            let lineData = lineBuffer.prefix(offset)
                            if let lineText = String(data: lineData, encoding: .utf8) {
                                sink(BrewCommandOutputLine(stream: stream, text: lineText))
                            }
                            lineBuffer = Data(lineBuffer.dropFirst(offset + 1))
                        }
                    }
                }
                continuation.resume(returning: fullOutput)
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
