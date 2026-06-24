//
//  BrewCommandExecutionContext+Live.swift
//  BrewCLI
//

import BrewCore
import Foundation

public extension BrewCommandExecutionContext {
    /// Production wiring: brew spawned through the user's login + interactive shell so the
    /// subprocess inherits the same environment the user sees in Terminal (see
    /// ``LoginShellBrewCommandRunner``).
    static func live() -> BrewCommandExecutionContext {
        BrewCommandExecutionContext(
            commandRunner: LoginShellBrewCommandRunner(),
            locator: BrewExecutableLocator(),
        )
    }
}
