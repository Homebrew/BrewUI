//
//  InstalledInventoryReading.swift
//  Brew
//

import Foundation

/// Read-only access to the cached installed inventory snapshot.
@MainActor
protocol InstalledInventoryReading: Sendable {
    func installedPackageIDs() async -> Set<BrewPackage.ID>
}
