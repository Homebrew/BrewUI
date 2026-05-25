//
//  InstalledInventoryReading.swift
//  Brew
//

import Foundation

/// Read-only access to the set of installed package identities (used for dependency "installed?" checks).
@MainActor
protocol InstalledInventoryReading: Sendable {
    func installedPackageIDs() async -> Set<InstalledBrewPackage.ID>
}
