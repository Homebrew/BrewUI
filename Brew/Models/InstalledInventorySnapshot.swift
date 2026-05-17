//
//  InstalledInventorySnapshot.swift
//  Brew
//

import Foundation

struct InstalledInventorySnapshot: Equatable {
    nonisolated static let defaultTTL: TimeInterval = 3600

    var fetchedAt: Date
    let packages: [BrewPackage]
    let graph: PackageDependencyGraph

    init(fetchedAt: Date, packages: [BrewPackage]) {
        self.fetchedAt = fetchedAt
        self.packages = packages
        graph = PackageDependencyGraph(packages: packages)
    }

    nonisolated func isStale(relativeTo now: Date = .now, ttl: TimeInterval = Self.defaultTTL) -> Bool {
        now.timeIntervalSince(fetchedAt) >= ttl
    }
}
