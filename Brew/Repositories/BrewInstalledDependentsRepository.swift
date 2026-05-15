//
//  BrewInstalledDependentsRepository.swift
//  Brew
//

import Foundation

struct BrewInstalledDependentsRepository: InstalledDependentsRepository {
    private let cache: InstalledInventoryCache

    init(cache: InstalledInventoryCache) {
        self.cache = cache
    }

    func installedDependents(for packageID: BrewPackage.ID) async -> [BrewPackage] {
        guard let snapshot = await cache.currentSnapshot() else {
            return []
        }
        return snapshot.graph.installedDependents(for: packageID)
    }
}
