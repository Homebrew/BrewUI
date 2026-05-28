//
//  InstalledInventoryCache.swift
//  Brew
//

import BrewCore
import Foundation

/// Shared installed-inventory storage with TTL semantics. Domain reads (packages, dependents) go through repositories, not this actor.
public actor InstalledInventoryCache {
    public enum CacheResult: Sendable {
        case fresh([InstalledBrewPackage])
        case stale([InstalledBrewPackage])
        case empty
    }

    private var snapshot: InstalledInventorySnapshot?

    public init() {}

    public func replace(_ snapshot: InstalledInventorySnapshot) {
        self.snapshot = snapshot
    }

    public func currentSnapshot() -> InstalledInventorySnapshot? {
        snapshot
    }

    public func cachedPackages() -> CacheResult {
        guard let snapshot else { return .empty }
        return snapshot.isStale() ? .stale(snapshot.packages) : .fresh(snapshot.packages)
    }
}
