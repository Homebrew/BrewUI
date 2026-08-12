//
//  BrewRunOptions.swift
//  BrewCore
//

import Foundation

/// How a subprocess run should surface its output.
///
/// Streaming, colour, and terminal-backing are orthogonal. Background reads use none of them (silent,
/// colourless, buffered, pipe-backed). Because colourised output may also be parsed (`brew doctor` is shown
/// in colour *and* parsed), the rule is the defensive one: any consumer that parses strips ANSI first —
/// colour is a display concern the parser must ignore.
public struct BrewRunOptions: Sendable {
    /// Called with each `\n`-delimited line as it arrives, for live console display. Nil = buffered, no streaming.
    public var lineObserver: (@Sendable (BrewCommandOutputLine) -> Void)?

    /// Homebrew strips colour off a non-TTY. Redundant when ``usesPseudoTerminal`` is set.
    public var forceColor: Bool

    /// Run against a pseudo-terminal instead of pipes, so `isatty` is true in the child: Homebrew emits
    /// its progress rendering, and libc line-buffers instead of block-buffering.
    ///
    /// The cost is that one device carries both streams, so they arrive merged and every line is
    /// attributed to ``BrewCommandOutputLine/Stream/stdout``. Runs whose output gets parsed stay on pipes.
    public var usesPseudoTerminal: Bool

    public init(
        lineObserver: (@Sendable (BrewCommandOutputLine) -> Void)? = nil,
        forceColor: Bool = false,
        usesPseudoTerminal: Bool = false,
    ) {
        self.lineObserver = lineObserver
        self.forceColor = forceColor
        self.usesPseudoTerminal = usesPseudoTerminal
    }
}
