//
//  ConsoleOutputStream.swift
//  BrewCore
//

import Foundation

/// A command's opt-in request to stream its subprocess output to the console.
///
/// Passing one to ``BrewCommandRunning/run(executableURL:arguments:console:)`` does two things: each
/// `\n`-delimited line is forwarded to ``sink`` as the subprocess emits it, and Homebrew is forced to
/// emit ANSI colour (it strips colour when stdout isn't a TTY, which a pipe never is). Commands whose
/// output is parsed omit it and get clean, colourless, buffered output.
///
/// Replaces the former task-local sink: the intent now travels explicitly through
/// ``BrewCommandExecutionContext`` and the `run` signature instead of an ambient scope.
public struct ConsoleOutputStream: Sendable {
    public let sink: @Sendable (BrewCommandOutputLine) -> Void

    public init(_ sink: @escaping @Sendable (BrewCommandOutputLine) -> Void) {
        self.sink = sink
    }
}
