//
//  BrewRunOptions.swift
//  BrewCore
//

import Foundation

/// How a subprocess run should surface its output.
///
/// Streaming and colour are orthogonal. A run can stream lines to the console without colour (a read shown as
/// a pill, whose output is parsed) or with colour (a display-only mutation). The invariant the scheduler keeps:
/// ``forceColor`` is only ever set when the output is display-only — never when it will be parsed — so colour
/// codes can't reach a parser.
public struct BrewRunOptions: Sendable {
    /// Called with each `\n`-delimited line as it arrives, for live console display. Nil = buffered, no streaming.
    public var lineObserver: (@Sendable (BrewCommandOutputLine) -> Void)?

    /// Force Homebrew to emit ANSI colour, which it strips off a non-TTY (a pipe). Display-only.
    public var forceColor: Bool

    public init(
        lineObserver: (@Sendable (BrewCommandOutputLine) -> Void)? = nil,
        forceColor: Bool = false,
    ) {
        self.lineObserver = lineObserver
        self.forceColor = forceColor
    }
}
