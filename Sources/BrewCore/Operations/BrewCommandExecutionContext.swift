//
//  BrewCommandExecutionContext.swift
//  BrewCore
//

import Foundation

/// Dependency bundle the ``BrewCommandCenter`` uses to run commands: how to spawn a subprocess and how to
/// locate the `brew` executable.
public struct BrewCommandExecutionContext: Sendable {
    public var commandRunner: BrewCommandRunning
    public var locator: BrewExecutableLocating

    public init(commandRunner: BrewCommandRunning, locator: BrewExecutableLocating) {
        self.commandRunner = commandRunner
        self.locator = locator
    }

    public func brewExecutableURL() throws -> URL {
        try locator.findBrewExecutable()
    }
}
