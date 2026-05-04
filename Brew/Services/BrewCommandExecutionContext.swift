//
//  BrewCommandExecutionContext.swift
//  Brew
//

import Foundation

/// Dependencies for mutating `brew` subprocess work passed into ``BrewMutatingCommand/run(in:)``.
struct BrewCommandExecutionContext {
    var commandRunner: BrewCommandRunning
    var locator: BrewExecutableLocating

    func brewExecutableURL() throws -> URL {
        try locator.findBrewExecutable()
    }
}

extension BrewCommandExecutionContext {
    /// Production wiring: real subprocess runner + default `brew` lookup (same pairing as ``BrewInstalledPackagesRepository/live()``).
    static func live() -> BrewCommandExecutionContext {
        BrewCommandExecutionContext(
            commandRunner: BrewCommandService(),
            locator: BrewExecutableLocator(),
        )
    }
}
