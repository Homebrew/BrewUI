//
//  BrewCommandCenterEnvironment.swift
//  Brew
//

import SwiftUI

extension EnvironmentValues {
    /// Mutating `brew` coordinator from the composition root (`BrewApp`).
    /// Previews and tests should inject ``NoopBrewCommandCenter`` or a test double.
    /// Inject with `.environment(\.brewCommandCenter, center)`; read with `@Environment(\.brewCommandCenter)`.
    @Entry var brewCommandCenter: (any BrewCommandCenter)?
}
