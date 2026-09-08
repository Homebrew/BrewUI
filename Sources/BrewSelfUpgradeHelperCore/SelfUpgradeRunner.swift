//
//  SelfUpgradeRunner.swift
//  BrewSelfUpgradeHelperCore
//

import Foundation

/// Deliberately `Foundation.Process` rather than the app's `BrewCommandService`: that path exists to stream a
/// pseudo-terminal into the console UI, and there is no UI here. Nobody is watching, so the transcript goes to
/// a file and only the exit status is reported back.
public struct SelfUpgradeRunner: Sendable {
    public struct Outcome: Sendable, Equatable {
        public let succeeded: Bool
        public let detail: String

        public init(succeeded: Bool, detail: String) {
            self.succeeded = succeeded
            self.detail = detail
        }
    }

    private let transcriptSink: @Sendable (String) -> Void

    public init(transcriptSink: @escaping @Sendable (String) -> Void = { _ in }) {
        self.transcriptSink = transcriptSink
    }

    public func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval,
    ) async -> Outcome {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            return Outcome(succeeded: false, detail: "no executable brew at \(executablePath)")
        }
        // `Process` and `Pipe` are not `Sendable`, so both are created and used entirely inside the worker.
        return await withCheckedContinuation { (continuation: CheckedContinuation<Outcome, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(
                    returning: runBlocking(
                        executablePath: executablePath,
                        arguments: arguments,
                        environment: environment,
                        timeout: timeout,
                    ),
                )
            }
        }
    }

    /// Synchronous on purpose: an upgrade is one long blocking wait on a helper process that does nothing
    /// else, and the alternative is threading a non-`Sendable` `Process` across concurrency boundaries.
    private func runBlocking(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval,
    ) -> Outcome {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = Self.environment(adding: environment)

        // One pipe for both streams: the transcript is read by a person, and interleaved is how it ran.
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice

        // Installed before `run()`, so a process that exits immediately cannot be missed.
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        do {
            try process.run()
        } catch {
            return Outcome(succeeded: false, detail: "could not launch \(executablePath): \(error)")
        }

        // Started before the wait: reading only after termination deadlocks once the output overruns a
        // pipe buffer, and `brew upgrade --cask` easily does.
        let drained = drainInBackground(pipe)

        var timedOut = false
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            terminate(process)
            // It will go now; without this the transcript could be read before the last write.
            exited.wait()
        }

        // The write end closes when the last descendant holding it exits, which is what ends the drain.
        drained.wait()

        if timedOut {
            return Outcome(succeeded: false, detail: "brew did not finish within \(Int(timeout))s")
        }
        let status = Self.exitCode(of: process)
        guard status == 0 else {
            return Outcome(succeeded: false, detail: "brew exited \(status)")
        }
        return Outcome(succeeded: true, detail: "brew \(arguments.joined(separator: " ")) succeeded")
    }

    // MARK: Output

    /// Emits `\n`-terminated lines as they arrive, so the transcript survives a helper killed mid-run.
    private func drainInBackground(_ pipe: Pipe) -> DispatchSemaphore {
        let finished = DispatchSemaphore(value: 0)
        // Read on this queue only, and never after `finished` is signalled.
        let handle = pipe.fileHandleForReading
        let sink = transcriptSink
        DispatchQueue.global(qos: .utility).async {
            var buffer = Data()
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty {
                    break
                }
                buffer.append(chunk)
                while let newline = buffer.firstIndex(of: 0x0A) {
                    let offset = buffer.distance(from: buffer.startIndex, to: newline)
                    sink(Self.text(of: buffer.prefix(offset)))
                    buffer = Data(buffer.dropFirst(offset + 1))
                }
            }
            if !buffer.isEmpty {
                sink(Self.text(of: buffer))
            }
            finished.signal()
        }
        return finished
    }

    /// Latin-1 as the fallback because it cannot fail on arbitrary bytes: a line brew wrote in some other
    /// encoding is still worth having in the log, mangled, rather than dropped.
    private static func text(of data: Data) -> String {
        String(bytes: data, encoding: .utf8) ?? String(bytes: data, encoding: .isoLatin1) ?? ""
    }

    // MARK: Termination

    /// A hung upgrade must not strand the user without an app: brew is stopped and the relaunch happens
    /// anyway, with the old version. Only brew itself is signalled — `Process` gives the child no session of
    /// its own, so signalling the group would signal this helper too.
    private func terminate(_ process: Process) {
        process.terminate()
        // SIGTERM is what a Ruby script traps; SIGKILL is for one that has stopped listening.
        if process.isRunning, kill(process.processIdentifier, SIGKILL) != 0 {
            log("could not kill brew (pid \(process.processIdentifier))")
        }
    }

    /// A signalled child becomes `128 + signal`, the shell convention, keeping "non-zero means failure".
    private static func exitCode(of process: Process) -> Int32 {
        process.terminationReason == .uncaughtSignal
            ? 128 + process.terminationStatus
            : process.terminationStatus
    }

    private func log(_ message: String) {
        transcriptSink(message)
    }

    // MARK: Environment

    /// Inherited, plus whatever the app pinned. Colour is stripped because the transcript is a file, and
    /// `HOMEBREW_NO_ENV_HINTS` keeps the hints out of it — neither changes what the upgrade does.
    static func environment(adding overrides: [String: String]) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["HOMEBREW_NO_COLOR"] = "1"
        environment["HOMEBREW_NO_ENV_HINTS"] = "1"
        for (key, value) in overrides {
            environment[key] = value
        }
        return environment
    }
}
