//
//  BrewRunOptions.swift
//  BrewCore
//

import Foundation

/// How a subprocess run should surface its output.
///
/// Streaming and colour are orthogonal. Background reads use neither (silent, colourless, buffered);
/// console-shown work uses both. Because colourised output may also be parsed (`brew doctor` is a coloured
/// pill *and* parsed), the rule is the defensive one: any consumer that parses strips ANSI first — colour is
/// a display concern the parser must ignore.
public struct BrewRunOptions: Sendable {
    /// Called with each `\n`-delimited line as it arrives, for live console display. Nil = buffered, no streaming.
    public var lineObserver: (@Sendable (BrewCommandOutputLine) -> Void)?

    /// Force Homebrew to emit ANSI colour, which it strips off a non-TTY (a pipe). Set for console-shown work.
    public var forceColor: Bool

    public init(
        lineObserver: (@Sendable (BrewCommandOutputLine) -> Void)? = nil,
        forceColor: Bool = false,
    ) {
        self.lineObserver = lineObserver
        self.forceColor = forceColor
    }
}
