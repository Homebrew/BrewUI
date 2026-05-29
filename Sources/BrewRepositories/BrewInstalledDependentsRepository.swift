//
//  BrewInstalledDependentsRepository.swift
//  BrewRepositories
//

import BrewCLI
import BrewCore
import BrewRepositoryInterfaces
import Foundation

public struct BrewInstalledDependentsRepository: InstalledDependentsRepository {
    private let cache: InstalledInventoryCache

    public init(cache: InstalledInventoryCache) {
        self.cache = cache
    }

    public func installedDependents(for packageID: InstalledBrewPackage.ID) async -> [InstalledBrewPackage] {
        guard let snapshot = await cache.currentSnapshot() else {
            return []
        }
        return snapshot.graph.installedDependents(for: packageID)
    }
}
