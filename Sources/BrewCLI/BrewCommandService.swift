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
    private let makeTerminal: @Sendable () throws -> PseudoTerminal

    public init() {
        self.init(makeTerminal: { try PseudoTerminal() })
    }

    /// Seam for testing the allocation-failure path, otherwise reachable only by exhausting the
    /// machine's pty devices.
    init(makeTerminal: @escaping @Sendable () throws -> PseudoTerminal) {
        self.makeTerminal = makeTerminal
    }

    public func run(
        executableURL: URL,
        arguments: [String],
        options: BrewRunOptions,
    ) async throws -> CommandOutput {
        try Task.checkCancellation()

        switch options.output {
        case .pipes:
            return try await runOnPipes(executableURL: executableURL, arguments: arguments, options: options)

        case .pseudoTerminal:
            guard let terminal = allocateTerminal() else {
                return try await runOnPipes(
                    executableURL: executableURL,
                    arguments: arguments,
                    options: Self.pipeFallback(from: options),
                )
            }
            return try await runOnPseudoTerminal(
                terminal: terminal,
                executableURL: executableURL,
                arguments: arguments,
                options: options,
            )
        }
    }

    /// Nil rather than throwing: the device pool is much smaller than `kern.tty.ptmx_max` suggests, and
    /// failing an install over it is a poor trade when the command runs fine on pipes.
    private func allocateTerminal() -> PseudoTerminal? {
        try? makeTerminal()
    }

    /// The terminal was what supplied colour, so on pipes Homebrew has to be told explicitly.
    static func pipeFallback(from options: BrewRunOptions) -> BrewRunOptions {
        var fallback = options
        fallback.output = .pipes(forceColor: true)
        return fallback
    }
}

// MARK: - Pseudo-terminal execution

private extension BrewCommandService {
    /// One device serves both streams, so they arrive interleaved, every line is reported as
    /// ``BrewCommandOutputLine/Stream/stdout``, and ``CommandOutput/standardError`` is empty. Callers that
    /// need the streams apart must stay on the pipe path.
    ///
    /// ``CommandOutput/standardOutput`` is the assembled transcript, not the verbatim bytes: raw pty
    /// bytes are a cursor script in which a whole download is one line of redraws.
    func runOnPseudoTerminal(
        terminal: PseudoTerminal,
        executableURL: URL,
        arguments: [String],
        options: BrewRunOptions,
    ) async throws -> CommandOutput {
        let childHasExited = TerminalDrainGate()
        let sink = options.lineObserver

        // Started before the spawn: the drain times out until there is something to read, and this
        // process still holds the replica open, so it cannot see a premature end-of-input.
        async let drained: String = Self.drainTerminal(terminal, sink: sink, gate: childHasExited)

        do {
            let result = try await Subprocess.run(
                .path(FilePath(executableURL.path)),
                arguments: Arguments(arguments),
                environment: Self.environment(for: options),
                platformOptions: Self.platformOptions(),
                input: .none,
                output: .fileDescriptor(terminal.replicaDescriptor, closeAfterSpawningProcess: false),
                error: .fileDescriptor(terminal.replicaDescriptor, closeAfterSpawningProcess: false),
                body: { _ in
                    // Runs once the child is spawned, the only safe moment to drop our replica copy.
                    terminal.closeReplica()
                },
            )

            childHasExited.open()
            let transcript = await drained
            terminal.closePrimary()
            try Task.checkCancellation()

            return CommandOutput(
                standardOutput: transcript,
                standardError: "",
                terminationStatus: Self.exitCode(from: result.terminationStatus),
            )
        } catch {
            // Reap the drain before rethrowing, so no thread is left parked on the primary.
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

    /// Goes through ``TerminalLineAssembler`` rather than splitting on newlines: a terminal's redraws are
    /// separated by carriage returns, so by the newline measure a whole download is one line.
    ///
    /// Stops once the child has exited and a poll interval has passed with nothing to read. Waiting for
    /// end-of-input instead would stall on any grandchild still holding the descriptor open.
    static func drainTerminal(
        _ terminal: PseudoTerminal,
        sink: (@Sendable (BrewCommandOutputLine) -> Void)?,
        gate: TerminalDrainGate,
    ) async -> String {
        await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            // `read` parks on `poll`; run it on a GCD worker rather than the cooperative pool.
            DispatchQueue.global(qos: .utility).async {
                var transcript = ""
                var undecoded = Data()
                var assembler = TerminalLineAssembler()
                var readFailure: Int32?

                loop: while true {
                    switch terminal.read() {
                    case let .data(chunk):
                        undecoded.append(chunk)
                        for event in assembler.consume(UTF8StreamDecoder.takeDecodablePrefix(&undecoded)) {
                            if case let .committed(line) = event {
                                transcript += line.text + "\n"
                            }
                            emit(event, sink: sink)
                        }
                    case .timedOut:
                        if gate.isOpen {
                            break loop
                        }
                    case .endOfInput:
                        break loop
                    case let .failed(code):
                        readFailure = code
                        break loop
                    }
                }

                // Output that ended without a trailing newline is settled by the stream ending.
                if let trailing = assembler.flush() {
                    transcript += trailing.text
                    sink?(BrewCommandOutputLine(stream: .stdout, line: trailing, isComplete: true))
                }
                // The exit status may still say success, so truncation has to say so itself.
                if let readFailure {
                    let notice = truncationNotice(errno: readFailure)
                    transcript += transcript.isEmpty || transcript.hasSuffix("\n") ? notice : "\n" + notice
                    sink?(BrewCommandOutputLine(stream: .stderr, text: notice))
                }
                continuation.resume(returning: transcript)
            }
        }
    }

    static func truncationNotice(errno code: Int32) -> String {
        "[output truncated: could not read the pseudo-terminal: \(PseudoTerminal.describe(errno: code))]"
    }

    /// Everything from a terminal is reported on stdout: one device carries both streams.
    static func emit(_ event: TerminalLineEvent, sink: (@Sendable (BrewCommandOutputLine) -> Void)?) {
        guard let sink else {
            return
        }
        switch event {
        case let .committed(line):
            sink(BrewCommandOutputLine(stream: .stdout, line: line, isComplete: true))
        case let .revised(line):
            sink(BrewCommandOutputLine(stream: .stdout, line: line, isComplete: false))
        }
    }
}

// MARK: - Pipe execution

private extension BrewCommandService {
    /// No terminal, so stdout and stderr stay distinct. The path for output that will be parsed.
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
                environment: Self.environment(for: options),
                platformOptions: Self.platformOptions(),
                input: .none,
                output: .sequence,
                error: .sequence,
                body: { execution in
                    // Drained concurrently: waiting for exit before reading deadlocks on large outputs.
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
                standardOutput: UTF8StreamDecoder.lossyString(outData),
                standardError: UTF8StreamDecoder.lossyString(errData),
                terminationStatus: Self.exitCode(from: result.terminationStatus),
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw BrewCommandError.launchFailed(underlying: String(describing: error))
        }
    }

    /// Returns the bytes verbatim for ``CommandOutput``, emitting `\n`-terminated lines as they arrive.
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
            // A mid-stream read failure still yields what was collected; the exit status decides success.
        }

        flushPartialLine(lineBuffer, stream: stream, sink: sink)
        return fullOutput
    }
}

// MARK: - Shared helpers

private extension BrewCommandService {
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
            sink(BrewCommandOutputLine(stream: stream, text: UTF8StreamDecoder.lossyString(buffer.prefix(offset))))
            buffer = Data(buffer.dropFirst(offset + 1))
        }
    }

    static func flushPartialLine(
        _ buffer: Data,
        stream: BrewCommandOutputLine.Stream,
        sink: (@Sendable (BrewCommandOutputLine) -> Void)?,
    ) {
        guard let sink, !buffer.isEmpty else {
            return
        }
        sink(BrewCommandOutputLine(stream: stream, text: UTF8StreamDecoder.lossyString(buffer)))
    }

    /// `createSession` is what makes the pty a *controlling* terminal rather than merely a terminal-shaped
    /// descriptor, and puts the child and its descendants in one process group. Teardown then signals the
    /// whole group, so cancelling an install stops the `curl` or `git` it is waiting on.
    static func platformOptions() -> PlatformOptions {
        var platformOptions = PlatformOptions()
        platformOptions.createSession = true
        platformOptions.teardownSequence = [
            .gracefulShutDown(toProcessGroup: true, allowedDurationToNextStep: .seconds(2)),
        ]
        return platformOptions
    }

    /// Homebrew strips colour off a non-TTY, so the pipe path forces it back on (`CLICOLOR_FORCE` covers
    /// the BSD-convention tools brew shells out to). The terminal path needs `TERM` instead: a GUI process
    /// launched from Finder inherits none, and without it tools treat the terminal as capability-less.
    static func environment(for options: BrewRunOptions) -> Environment {
        switch options.output {
        case .pseudoTerminal:
            .inherit.updating(["TERM": "xterm-256color"])
        case let .pipes(forceColor):
            forceColor ? .inherit.updating(["HOMEBREW_COLOR": "1", "CLICOLOR_FORCE": "1"]) : .inherit
        }
    }

    /// A signalled child becomes `128 + signal`, the shell convention, keeping "non-zero means failure".
    static func exitCode(from status: TerminationStatus) -> Int32 {
        switch status {
        case let .exited(code):
            code
        case let .signaled(signal):
            128 + signal
        }
    }
}

/// Tells the drain the child has exited, so a quiet terminal means "finished" rather than "waiting".
/// Set from the task awaiting the subprocess, read from the drain's GCD worker, hence the lock.
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
