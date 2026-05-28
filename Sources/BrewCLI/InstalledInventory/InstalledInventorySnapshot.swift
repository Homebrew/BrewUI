//
//  InstalledInventorySnapshot.swift
//  Brew
//

import BrewCore
import Foundation

public nonisolated struct InstalledInventorySnapshot: Equatable, Sendable {
    public nonisolated static let defaultTTL: TimeInterval = 3600

    public var fetchedAt: Date
    public let packages: [InstalledBrewPackage]
    public let graph: PackageDependencyGraph

    public init(fetchedAt: Date, packages: [InstalledBrewPackage]) {
        self.fetchedAt = fetchedAt
        self.packages = packages
        graph = PackageDependencyGraph(packages: packages)
    }

    public nonisolated func isStale(relativeTo now: Date = .now, ttl: TimeInterval = Self.defaultTTL) -> Bool {
        now.timeIntervalSince(fetchedAt) >= ttl
    }
}
