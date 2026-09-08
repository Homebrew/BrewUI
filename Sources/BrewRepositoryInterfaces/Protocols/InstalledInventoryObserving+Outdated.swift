//
//  InstalledInventoryObserving+Outdated.swift
//  BrewRepositoryInterfaces
//

import BrewCore

@MainActor
public extension InstalledInventoryObserving {
    /// The loaded inventory minus the app's own cask, which the self-upgrade banner owns. Every list, count
    /// and batch reads this; `state` stays unfiltered so the self-upgrade detector can still find it there.
    /// Reads `state` through the `Observable` existential so SwiftUI re-renders
    /// callers when the inventory reconciles after a mutating operation.
    var userManagedPackages: [InstalledBrewPackage] {
        (state.value ?? []).filter { !$0.isTheAppsOwnCask }
    }

    /// Outdated subset of the loaded inventory; empty while loading or failed.
    var outdatedPackages: [InstalledBrewPackage] {
        userManagedPackages.filter(\.outdated)
    }

    /// Count for the sidebar badge / Upgrades subtitle.
    var outdatedCount: Int {
        outdatedPackages.count
    }

    var isTheAppsOwnCaskOutdated: Bool {
        (state.value ?? []).contains { $0.isTheAppsOwnCask && $0.outdated }
    }
}
