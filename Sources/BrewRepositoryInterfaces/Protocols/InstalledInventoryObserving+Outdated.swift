//
//  InstalledInventoryObserving+Outdated.swift
//  BrewRepositoryInterfaces
//

import BrewCore

@MainActor
public extension InstalledInventoryObserving {
    /// Outdated subset of the loaded inventory; empty while loading or failed.
    /// Reads `state` through the `Observable` existential so SwiftUI re-renders
    /// callers when the inventory reconciles after a mutating operation.
    var outdatedPackages: [InstalledBrewPackage] {
        (state.value ?? []).filter(\.outdated)
    }

    /// Count for the sidebar badge / Updates subtitle.
    var outdatedCount: Int {
        outdatedPackages.count
    }
}
