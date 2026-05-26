//
//  JobRegistryEnvironment.swift
//  Brew
//

import SwiftUI

extension EnvironmentValues {
    /// Console-side projection of command-center operations, owned by the composition root (`BrewApp`).
    /// Inject with `.environment(\.jobRegistry, registry)`; read with `@Environment(\.jobRegistry)`.
    @Entry var jobRegistry: JobRegistry = .init()
}
