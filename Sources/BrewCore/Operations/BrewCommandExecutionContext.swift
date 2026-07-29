//
//  BrewCommandExecutionContext.swift
//  BrewCore
//

import Foundation

/// Dependencies for mutating `brew` subprocess work passed into ``BrewMutatingCommand/run(in:)``.
public struct BrewCommandExecutionContext: Sendable {
    public var commandRunner: BrewCommandRunning
    public var locator: BrewExecutableLocating

    /// Present when this command's output is streamed to the console (and thus wants colour). The command
    /// center sets it per-operation; commands forward it into ``BrewCommandRunning/run(executableURL:arguments:console:)``.
    /// Nil for direct/parsed use, so read commands stay clean.
    public var console: ConsoleOutputStream?

    public init(
        commandRunner: BrewCommandRunning,
        locator: BrewExecutableLocating,
        console: ConsoleOutputStream? = nil,
    ) {
        self.commandRunner = commandRunner
        self.locator = locator
        self.console = console
    }

    public func brewExecutableURL() throws -> URL {
        try locator.findBrewExecutable()
    }
}
