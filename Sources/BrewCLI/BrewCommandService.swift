//
//  BrewCommandService.swift
//  Brew
//

import BrewCore
import Foundation
import Subprocess
import System

/// Subprocess runner for Homebrew CLI (`ARCHITECTURE.md` — Command execution).
public struct BrewCommandService: BrewCommandRunning {
    public init() {}

    public func run(
        executableURL: URL,
        arguments: [String],
        options: BrewRunOptions,
    ) async throws -> CommandOutput {
        try Task.checkCancellation()

        if options.usesPseudoTerminal {
            return try await runOnPseudoTerminal(
                executableURL: executableURL,
                arguments: arguments,
                options: options,
            )
        }
        return try await runOnPipes(
            executableURL: executableURL,
            arguments: arguments,
            options: options,
        )
    }
}

// MARK: - Pseudo-terminal execution

private extension BrewCommandService {
    /// Runs the child against a pty, so `isatty` holds and Homebrew emits colour and progress on its own.
    ///
    /// One terminal device serves both stdout and stderr — that is what a terminal *is* — so the two
    /// streams arrive interleaved in write order and every line is reported as
    /// ``BrewCommandOutputLine/Stream/stdout``. ``CommandOutput/standardError`` is empty for these runs;
    /// callers that need the streams apart must stay on the pipe path.
    func runOnPseudoTerminal(
        executableURL: URL,
        arguments: [String],
        options: BrewRunOptions,
    ) async throws -> CommandOutput {
        let terminal = try PseudoTerminal()
        let childHasExited = TerminalDrainGate()
        let sink = options.lineObserver

        // Started before the spawn deliberately: the drain simply times out until there is something to
        // read, and this process still holds the replica open, so it cannot see a premature end-of-input.
        async let drained: Data = Self.drainTerminal(terminal, sink: sink, gate: childHasExited)

        do {
            let result = try await Subprocess.run(
                .path(FilePath(executableURL.path)),
                arguments: Arguments(arguments),
                environment: Self.environment(for: options, isTerminal: true),
                platformOptions: Self.platformOptions(),
                input: .none,
                output: .fileDescriptor(terminal.replicaDescriptor, closeAfterSpawningProcess: false),
                error: .fileDescriptor(terminal.replicaDescriptor, closeAfterSpawningProcess: false),
                body: { _ in
                    // Runs once the child is spawned, which is the only safe moment to drop this
                    // process's copy of the replica — see the ownership note on `PseudoTerminal`.
                    terminal.closeReplica()
                },
            )

            childHasExited.open()
            let data = await drained
            terminal.closePrimary()
            try Task.checkCancellation()

            return CommandOutput(
                standardOutput: String(bytes: data, encoding: .utf8) ?? "",
                standardError: "",
                terminationStatus: Self.exitCode(from: result.terminationStatus),
            )
        } catch {
            // Unblock and reap the drain before rethrowing, so no thread is left parked on the primary.
            terminal.closeReplica()
            childHasExited.open()
            _ = await drained
            terminal.closePrimary()

            if error is CancellationError {
                throw error
            }
            throw BrewCommandError.launchFailed(underlying: String(describing: error))
        }
    }

    /// Drains the terminal to end-of-input, emitting lines through `sink` as they arrive.
    ///
    /// Stops early when the child has exited and a full poll interval has passed with nothing to read.
    /// That combination — process gone, terminal quiet — is what distinguishes "finished" from "a
    /// grandchild is still holding the descriptor open", which would otherwise stall here indefinitely.
    static func drainTerminal(
        _ terminal: PseudoTerminal,
        sink: (@Sendable (BrewCommandOutputLine) -> Void)?,
        gate: TerminalDrainGate,
    ) async -> Data {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
            // `read` parks on `poll`; run it on a GCD worker rather than the cooperative pool.
            DispatchQueue.global(qos: .utility).async {
                var fullOutput = Data()
                var lineBuffer = Data()

                loop: while true {
                    switch terminal.read() {
                    case let .data(chunk):
                        fullOutput.append(chunk)
                        if sink != nil {
                            lineBuffer.append(chunk)
                            emitCompleteLines(from: &lineBuffer, stream: .stdout, sink: sink)
                        }
                    case .timedOut:
                        if gate.isOpen {
                            break loop
                        }
                    case .endOfInput:
                        break loop
                    }
                }

                flushPartialLine(lineBuffer, stream: .stdout, sink: sink)
                continuation.resume(returning: fullOutput)
            }
        }
    }
}

// MARK: - Pipe execution

private extension BrewCommandService {
    /// Runs the child against pipes: no terminal, stdout and stderr stay distinct. The path for output
    /// that will be parsed.
    func runOnPipes(
        executableURL: URL,
        arguments: [String],
        options: BrewRunOptions,
    ) async throws -> CommandOutput {
        let sink = options.lineObserver

        do {
            let result = try await Subprocess.run(
                .path(FilePath(executableURL.path)),
                arguments: Arguments(arguments),
                environment: Self.environment(for: options, isTerminal: false),
                platformOptions: Self.platformOptions(),
                input: .none,
                output: .sequence,
                error: .sequence,
                body: { execution in
                    // Drained concurrently: waiting for exit before reading deadlocks on large outputs
                    // such as `brew info --installed --json=v2`.
                    async let outRead = Self.drainSequence(
                        execution.standardOutput,
                        stream: .stdout,
                        sink: sink,
                    )
                    async let errRead = Self.drainSequence(
                        execution.standardError,
                        stream: .stderr,
                        sink: sink,
                    )
                    return await (outRead, errRead)
                },
            )

            try Task.checkCancellation()
            let (outData, errData) = result.closureResult
            return CommandOutput(
                standardOutput: String(bytes: outData, encoding: .utf8) ?? "",
                standardError: String(bytes: errData, encoding: .utf8) ?? "",
                terminationStatus: Self.exitCode(from: result.terminationStatus),
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw BrewCommandError.launchFailed(underlying: String(describing: error))
        }
    }

    /// Drains one of the subprocess's output streams, returning the raw bytes verbatim for
    /// ``CommandOutput`` and emitting `\n`-terminated lines through `sink` as they arrive.
    static func drainSequence(
        _ sequence: SubprocessOutputSequence,
        stream: BrewCommandOutputLine.Stream,
        sink: (@Sendable (BrewCommandOutputLine) -> Void)?,
    ) async -> Data {
        var fullOutput = Data()
        var lineBuffer = Data()

        do {
            for try await buffer in sequence {
                let chunk = buffer.withUnsafeBytes { Data($0) }
                fullOutput.append(chunk)
                if sink != nil {
                    lineBuffer.append(chunk)
                    emitCompleteLines(from: &lineBuffer, stream: stream, sink: sink)
                }
            }
        } catch {
            // A read failure mid-stream still yields whatever was already collected; the exit status
            // carried alongside it is what decides success or failure.
        }

        flushPartialLine(lineBuffer, stream: stream, sink: sink)
        return fullOutput
    }
}

// MARK: - Shared helpers

private extension BrewCommandService {
    /// Emits every complete `\n`-terminated line sitting in `buffer`, leaving any trailing partial line.
    /// Lines whose bytes aren't valid UTF-8 are dropped from the stream (they remain in the verbatim bytes).
    static func emitCompleteLines(
        from buffer: inout Data,
        stream: BrewCommandOutputLine.Stream,
        sink: (@Sendable (BrewCommandOutputLine) -> Void)?,
    ) {
        guard let sink else {
            return
        }
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let offset = buffer.distance(from: buffer.startIndex, to: newlineIndex)
            let lineData = buffer.prefix(offset)
            if let lineText = String(bytes: lineData, encoding: .utf8) {
                sink(BrewCommandOutputLine(stream: stream, text: lineText))
            }
            buffer = Data(buffer.dropFirst(offset + 1))
        }
    }

    /// Emits a trailing line that arrived without a terminating newline.
    static func flushPartialLine(
        _ buffer: Data,
        stream: BrewCommandOutputLine.Stream,
        sink: (@Sendable (BrewCommandOutputLine) -> Void)?,
    ) {
        guard let sink, !buffer.isEmpty, let text = String(bytes: buffer, encoding: .utf8) else {
            return
        }
        sink(BrewCommandOutputLine(stream: stream, text: text))
    }

    /// `createSession` puts the child in its own session, which is what makes the pty a *controlling*
    /// terminal rather than merely a terminal-shaped descriptor, and it gives the child and everything it
    /// spawns a process group of their own. Teardown then signals that whole group, so cancelling an
    /// install also stops the `curl` or `git` it is waiting on instead of orphaning it.
    static func platformOptions() -> PlatformOptions {
        var platformOptions = PlatformOptions()
        platformOptions.createSession = true
        platformOptions.teardownSequence = [
            .gracefulShutDown(toProcessGroup: true, allowedDurationToNextStep: .seconds(2)),
        ]
        return platformOptions
    }

    /// Homebrew strips colour when stdout isn't a TTY, so the pipe path forces it back on via
    /// `HOMEBREW_COLOR` (and `CLICOLOR_FORCE` for the BSD-convention tools brew shells out to). The
    /// terminal path needs neither — it *is* a TTY — but does need `TERM`, which a GUI process launched
    /// from Finder or launchd does not inherit; without it, tools treat the terminal as capability-less
    /// and suppress the colour and progress rendering the pty was allocated to get.
    static func environment(for options: BrewRunOptions, isTerminal: Bool) -> Environment {
        if isTerminal {
            return .inherit.updating(["TERM": "xterm-256color"])
        }
        guard options.forceColor else {
            return .inherit
        }
        return .inherit.updating(["HOMEBREW_COLOR": "1", "CLICOLOR_FORCE": "1"])
    }

    /// Maps a termination status onto the `Int32` exit code ``CommandOutput`` carries. A signalled child
    /// becomes `128 + signal`, the shell convention, which keeps "non-zero means failure" true.
    static func exitCode(from status: TerminationStatus) -> Int32 {
        switch status {
        case let .exited(code):
            code
        case let .signaled(signal):
            128 + signal
        }
    }
}

/// One-way flag telling the terminal drain that the child has exited, so a quiet terminal now means
/// "finished" rather than "waiting". Set from the task that awaits the subprocess, read from the drain's
/// GCD worker, hence the lock.
// swiftlint:disable:next unchecked_sendable
private final class TerminalDrainGate: @unchecked Sendable {
    private let lock = NSLock()
    private var opened = false

    var isOpen: Bool {
        lock.lock()
        defer { lock.unlock() }
        return opened
    }

    func open() {
        lock.lock()
        defer { lock.unlock() }
        opened = true
    }
}
