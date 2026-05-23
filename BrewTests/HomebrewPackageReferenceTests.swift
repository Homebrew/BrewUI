//
//  HomebrewPackageReferenceTests.swift
//  BrewTests
//

@testable import Brew
import Testing

struct HomebrewPackageIDTests {
    @Test func `id is the reference itself`() {
        let reference = HomebrewPackageID.formula(name: "wget")
        #expect(reference.id == reference)
    }

    @Test func `uniqueReferences deduplicates by kind and name`() {
        let references = HomebrewPackageID.uniqueReferences([
            .formula(name: "openssl@3"),
            .formula(name: "openssl@3"),
            .cask(token: "docker"),
            .cask(token: "docker"),
        ])

        #expect(references == [.formula(name: "openssl@3"), .cask(token: "docker")])
    }

    @Test func `formulaDependencies applies uniqueReferences`() {
        let references = HomebrewPackageID.formulaDependencies(from: [
            "openssl@3",
            "openssl@3",
        ])

        #expect(references == [.formula(name: "openssl@3")])
    }

    @Test func `init from package preserves kind and name`() {
        let formula = BrewPackage.fixture(name: "wget", kind: .formula)
        let cask = BrewPackage.fixture(name: "docker", kind: .cask)

        #expect(HomebrewPackageID(package: formula) == .formula(name: "wget"))
        #expect(HomebrewPackageID(package: cask) == .cask(token: "docker"))
    }
}
