//
//  HomebrewPackageReferenceTests.swift
//  BrewTests
//

@testable import Brew
import Testing

struct HomebrewPackageReferenceTests {
    @Test func `packageID encodes formula and cask references`() {
        #expect(HomebrewPackageReference.formula(name: "openssl@3").packageID == "formula:openssl@3")
        #expect(HomebrewPackageReference.cask(token: "docker").packageID == "cask:docker")
    }

    @Test func `uniqueReferences trims whitespace and drops empty names`() {
        let references = HomebrewPackageReference.uniqueReferences([
            .formula(name: "  openssl@3  "),
            .formula(name: ""),
            .formula(name: "   "),
            .cask(token: " docker "),
        ])

        #expect(references == [.formula(name: "openssl@3"), .cask(token: "docker")])
    }

    @Test func `uniqueReferences deduplicates by kind and name`() {
        let references = HomebrewPackageReference.uniqueReferences([
            .formula(name: "openssl@3"),
            .formula(name: "openssl@3"),
            .cask(token: "docker"),
            .cask(token: "docker"),
        ])

        #expect(references == [.formula(name: "openssl@3"), .cask(token: "docker")])
    }

    @Test func `formulaDependencies applies uniqueReferences`() {
        let references = HomebrewPackageReference.formulaDependencies(from: [
            "openssl@3",
            " openssl@3 ",
            "",
        ])

        #expect(references == [.formula(name: "openssl@3")])
    }

    @Test func `init from package preserves kind and name`() {
        let formula = BrewPackage.fixture(name: "wget", kind: .formula)
        let cask = BrewPackage.fixture(name: "docker", kind: .cask)

        #expect(HomebrewPackageReference(package: formula) == .formula(name: "wget"))
        #expect(HomebrewPackageReference(package: cask) == .cask(token: "docker"))
    }
}
