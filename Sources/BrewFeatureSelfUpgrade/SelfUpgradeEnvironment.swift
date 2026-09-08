//
//  SelfUpgradeEnvironment.swift
//  BrewFeatureSelfUpgrade
//

import SwiftUI

public extension EnvironmentValues {
    /// Injected by the composition root. `nil` in previews and tests, where no banner shows.
    @Entry var selfUpgradeCoordinator: SelfUpgradeCoordinator?
}
