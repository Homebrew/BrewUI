//
//  BrewCommandExecutionContext+Live.swift
//  BrewCLI
//

import BrewCore
import Foundation

public extension BrewCommandExecutionContext {
    /// Production wiring: system zsh, a restricted PATH and settings loaded by Homebrew from `brew.env`.
    static func live() -> BrewCommandExecutionContext {
        BrewCommandExecutionContext(
            commandRunner: ZshBrewCommandRunner(),
            locator: BrewExecutableLocator(),
        )
    }
}
