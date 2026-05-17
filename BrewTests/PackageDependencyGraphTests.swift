//
//  PackageDependencyGraphTests.swift
//  BrewTests
//

@testable import Brew
import Testing

struct PackageDependencyGraphTests {
    @Test func `installedDependents for package id returns sorted dependents`() {
        let packages = [
            BrewPackage.fixture(name: "openssl@3", kind: .formula, dependencies: []),
            BrewPackage.fixture(name: "node", kind: .formula, dependencies: [.formula(name: "openssl@3")]),
            BrewPackage.fixture(name: "curl", kind: .formula, dependencies: [.formula(name: "openssl@3")]),
        ]
        let graph = PackageDependencyGraph(packages: packages)
        let openssl = packages[0]
        #expect(graph.installedDependents(for: openssl.id).map(\.name) == ["curl", "node"])
    }

    @Test func `installedDependents for package id is empty when id is unknown`() {
        let graph = PackageDependencyGraph(packages: [
            BrewPackage.fixture(name: "wget", kind: .formula, dependencies: [.formula(name: "zlib")]),
        ])
        #expect(graph.installedDependents(for: BrewPackage.ID("unknown")).isEmpty)
    }

    @Test func `installedDependents for package id is empty when no installed package depends on id`() {
        let graph = PackageDependencyGraph(packages: [
            BrewPackage.fixture(name: "wget", kind: .formula, dependencies: [.formula(name: "zlib")]),
        ])
        #expect(graph.installedDependents(for: "formula:openssl@3").isEmpty)
    }

    @Test func `installedDependents distinguishes formula and cask dependency references`() {
        let packages = [
            BrewPackage.fixture(name: "shared", kind: .formula, dependencies: []),
            BrewPackage.fixture(name: "shared", kind: .cask, dependencies: []),
            BrewPackage.fixture(
                name: "consumer",
                kind: .cask,
                dependencies: [.formula(name: "shared")],
            ),
        ]
        let graph = PackageDependencyGraph(packages: packages)
        #expect(graph.installedDependents(for: "formula:shared").map(\.name) == ["consumer"])
        #expect(graph.installedDependents(for: "cask:shared").isEmpty)
    }
}
