//
//  BrewCommandExecutionContext+Live.swift
//  BrewCLI
//

import BrewCore
import Foundation

public extension BrewCommandExecutionContext {
    /// Production wiring: real subprocess runner + default `brew` lookup.
    static func live() -> BrewCommandExecutionContext {
        BrewCommandExecutionContext(
            commandRunner: BrewCommandService(),
            locator: BrewExecutableLocator(),
        )
    }
}
