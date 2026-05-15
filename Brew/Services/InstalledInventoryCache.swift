//
//  InstalledInventoryCache.swift
//  Brew
//

import Foundation

/// Shared installed-inventory storage with TTL semantics. Domain reads (packages, dependents) go through repositories, not this actor.
actor InstalledInventoryCache {
    enum CacheResult {
        case fresh([BrewPackage])
        case stale([BrewPackage])
        case empty
    }

    private var snapshot: InstalledInventorySnapshot?

    func replace(_ snapshot: InstalledInventorySnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> InstalledInventorySnapshot? {
        snapshot
    }

    func cachedPackages() -> CacheResult {
        guard let snapshot else { return .empty }
        return snapshot.isStale() ? .stale(snapshot.packages) : .fresh(snapshot.packages)
    }
}
