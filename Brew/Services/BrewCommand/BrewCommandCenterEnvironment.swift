//
//  BrewCommandCenterEnvironment.swift
//  Brew
//

import SwiftUI

extension EnvironmentValues {
    /// Mutating `brew` coordinator from the composition root (`BrewApp`).
    /// Inject with `.environment(\.brewCommandCenter, center)`; read with `@Environment(\.brewCommandCenter)`.
    @Entry var brewCommandCenter: (any BrewCommandCenter) = SerialBrewCommandCenter(executionContext: .live())
}
