//
//  InstalledInventoryObserving+TopLevel.swift
//  BrewRepositoryInterfaces
//

import BrewCore

@MainActor
public extension InstalledInventoryObserving {
    /// Package IDs that at least one user-managed installed package declares as a dependency.
    /// A package absent from this set is "top-level" (`brew leaves` semantics): nothing
    /// installed depends on it. Edges come from the full inventory rather than any filtered
    /// subset, so the Upgrades page does not misclassify a package whose only dependent is
    /// itself up to date.
    var userManagedDependencyPackageIDs: Set<HomebrewPackageID> {
        Set(userManagedPackages.flatMap(\.dependencies))
    }
}
