//
//  InstalledInventorySnapshot.swift
//  Brew
//

import Foundation

struct InstalledInventorySnapshot: Equatable {
    nonisolated static let defaultTTL: TimeInterval = 3600

    var fetchedAt: Date
    let packages: [InstalledBrewPackage]
    let graph: PackageDependencyGraph

    init(fetchedAt: Date, packages: [InstalledBrewPackage]) {
        self.fetchedAt = fetchedAt
        self.packages = packages
        graph = PackageDependencyGraph(packages: packages)
    }

    nonisolated func isStale(relativeTo now: Date = .now, ttl: TimeInterval = Self.defaultTTL) -> Bool {
        now.timeIntervalSince(fetchedAt) >= ttl
    }
}
