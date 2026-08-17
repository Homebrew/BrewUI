//
//  BrewRunOptions.swift
//  BrewCore
//

import Foundation

/// How a subprocess run should surface its output.
///
/// Streaming and the output channel are orthogonal. Background reads use neither (silent, buffered,
/// pipe-backed, colourless). Because colourised output may also be parsed (`brew doctor` is shown in
/// colour *and* parsed), the rule is the defensive one: any consumer that parses strips ANSI first —
/// colour is a display concern the parser must ignore.
public struct BrewRunOptions: Sendable {
    /// Where the child's stdout and stderr go.
    public enum OutputChannel: Equatable, Sendable {
        /// Separate pipes, so the streams stay distinct. The path for output that gets parsed.
        /// Homebrew strips colour off a pipe, hence the explicit ask.
        case pipes(forceColor: Bool)

        /// A pseudo-terminal, so `isatty` is true in the child: Homebrew emits its own progress
        /// rendering and libc line-buffers. One device carries both streams, so they arrive merged,
        /// every line is attributed to stdout, and ``CommandOutput/standardError`` comes back empty.
        case pseudoTerminal
    }

    /// Called with each line as it arrives, for live console display. Nil = buffered, no streaming.
    public var lineObserver: (@Sendable (BrewCommandOutputLine) -> Void)?

    public var output: OutputChannel

    public init(
        lineObserver: (@Sendable (BrewCommandOutputLine) -> Void)? = nil,
        output: OutputChannel = .pipes(forceColor: false),
    ) {
        self.lineObserver = lineObserver
        self.output = output
    }
}
