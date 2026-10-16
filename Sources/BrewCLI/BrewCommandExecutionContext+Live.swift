//
//  BrewCommandExecutionContext+Live.swift
//  BrewCLI
//

import BrewCore
import Foundation

public extension BrewCommandExecutionContext {
    /// Production wiring: system zsh, a restricted PATH and settings loaded by Homebrew from `brew.env`.
    /// `askpassURL` has no default so a new caller cannot drop sudo prompts by accident.
    static func live(askpassURL: URL) -> BrewCommandExecutionContext {
        BrewCommandExecutionContext(
            commandRunner: ZshBrewCommandRunner(askpassExecutableURL: askpassURL),
            locator: BrewExecutableLocator(),
        )
    }
}
