//
//  InstalledInventoryReading.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

/// Read-only access to the set of installed package identities (used for dependency "installed?" checks).
@MainActor
public protocol InstalledInventoryReading: Sendable {
    func installedPackageIDs() async -> Set<InstalledBrewPackage.ID>
}
