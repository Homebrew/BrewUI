//
//  InstalledInventorySnapshotTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import BrewCoreTestSupport
import BrewServicesTestSupport
import Foundation
import Testing

struct InstalledInventorySnapshotTests {
    @Test func `isStale is false before default TTL elapses`() {
        let fetchedAt = Date(timeIntervalSinceReferenceDate: 0)
        let snapshot = InstalledInventorySnapshot(fetchedAt: fetchedAt, packages: [])
        let ttl = InstalledInventorySnapshot.defaultTTL

        #expect(!snapshot.isStale(relativeTo: fetchedAt.addingTimeInterval(ttl - 1), ttl: ttl))
    }

    @Test func `isStale is true at default TTL boundary`() {
        let fetchedAt = Date(timeIntervalSinceReferenceDate: 0)
        let snapshot = InstalledInventorySnapshot(fetchedAt: fetchedAt, packages: [])
        let ttl = InstalledInventorySnapshot.defaultTTL

        #expect(snapshot.isStale(relativeTo: fetchedAt.addingTimeInterval(ttl), ttl: ttl))
    }

    @Test func `isStale respects custom TTL`() {
        let fetchedAt = Date(timeIntervalSinceReferenceDate: 0)
        let snapshot = InstalledInventorySnapshot(fetchedAt: fetchedAt, packages: [])
        let ttl: TimeInterval = 60

        #expect(!snapshot.isStale(relativeTo: fetchedAt.addingTimeInterval(ttl - 1), ttl: ttl))
        #expect(snapshot.isStale(relativeTo: fetchedAt.addingTimeInterval(ttl), ttl: ttl))
    }

    @Test func `graph matches standalone dependency graph for packages`() {
        let packages = [
            InstalledBrewPackage.fixture(name: "openssl@3", kind: .formula, dependencies: []),
            InstalledBrewPackage.fixture(name: "node", kind: .formula, dependencies: [.formula(name: "openssl@3")]),
        ]
        let snapshot = InstalledInventorySnapshot(fetchedAt: .now, packages: packages)
        let standalone = PackageDependencyGraph(packages: packages)
        let opensslID = packages[0].id

        #expect(snapshot.graph.installedDependents(for: opensslID) == standalone.installedDependents(for: opensslID))
    }
}
