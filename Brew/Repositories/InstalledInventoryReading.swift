//
//  InstalledInventoryReading.swift
//  Brew
//

import Foundation

/// Read-only access to the cached installed inventory snapshot.
@MainActor
protocol InstalledInventoryReading: Sendable {
    func installedPackageIDs() async -> Set<InstalledBrewPackage.ID>
    func installedPackages() async -> [InstalledBrewPackage]
}
