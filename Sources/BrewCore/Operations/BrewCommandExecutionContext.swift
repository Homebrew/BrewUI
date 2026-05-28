//
//  BrewCommandExecutionContext.swift
//  BrewCore
//

import Foundation

/// Dependencies for mutating `brew` subprocess work passed into ``BrewMutatingCommand/run(in:)``.
public struct BrewCommandExecutionContext {
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
