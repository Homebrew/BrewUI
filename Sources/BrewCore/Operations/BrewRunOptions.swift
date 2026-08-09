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

    /// Force Homebrew to emit ANSI colour, which it strips off a non-TTY (a pipe). Set for console-shown work
    /// that stays pipe-backed. Redundant when ``usesPseudoTerminal`` is set — a terminal gets colour anyway.
    public var forceColor: Bool

    /// Run the subprocess against a pseudo-terminal instead of pipes, so `isatty` is true in the child.
    ///
    /// Two consequences, both wanted for console-shown work: Homebrew and the tools it shells out to emit
    /// their progress rendering, and libc switches from block buffering to line buffering so output arrives
    /// as it is produced rather than in multi-kilobyte bursts.
    ///
    /// The cost is that a single terminal device carries both streams, so stdout and stderr arrive merged
    /// and every line is attributed to ``BrewCommandOutputLine/Stream/stdout``. Runs whose output gets
    /// parsed should leave this off and stay on pipes, where the two streams remain distinct.
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
