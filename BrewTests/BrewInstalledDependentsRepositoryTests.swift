//
//  BrewInstalledDependentsRepositoryTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct BrewInstalledDependentsRepositoryTests {
    @Test @MainActor func `installedDependents resolves reverse dependencies from cached snapshot`() async {
        let cache = InstalledInventoryCache()
        let snapshot = InstalledInventorySnapshot(
            fetchedAt: .now,
            packages: [
                .fixture(name: "openssl@3", kind: .formula, dependencies: []),
                .fixture(name: "node", kind: .formula, dependencies: [.formula(name: "openssl@3")]),
            ],
        )
        await cache.replace(snapshot)
        let repository = BrewInstalledDependentsRepository(cache: cache)
        let openssl = snapshot.packages.first(where: { $0.name == "openssl@3" })
        guard let openssl else {
            Issue.record("expected openssl@3 in snapshot")
            return
        }

        let dependents = await repository.installedDependents(for: openssl.id)

        #expect(dependents.map(\.name) == ["node"])
    }

    @Test @MainActor func `installedDependents returns empty when cache has no snapshot`() async {
        let cache = InstalledInventoryCache()
        let repository = BrewInstalledDependentsRepository(cache: cache)

        let dependents = await repository.installedDependents(for: "formula:openssl@3")

        #expect(dependents.isEmpty)
    }
}
