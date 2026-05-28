//
//  PackageRelationshipItemTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositories
import BrewRepositoriesLive
import BrewRepositoriesTestSupport
import BrewServicesTestSupport
import Testing

struct PackageRelationshipItemTests {
    @Test @MainActor func `dependency marks installed reference with package id`() {
        let reference = HomebrewPackageID.formula(name: "openssl@3")
        let item = PackageRelationshipItem.dependency(
            reference,
            installedPackageIDs: [.formula(name: "openssl@3")],
        )

        #expect(item.displayName == "openssl@3")
        #expect(item.packageKind == .formula)
        #expect(item.targetPackageID == .formula(name: "openssl@3"))
        #expect(item.installedPackageID == .formula(name: "openssl@3"))
        #expect(item.isInstalledInInventory)
        #expect(item.id == .formula(name: "openssl@3"))
    }

    @Test @MainActor func `dependency marks missing reference without installed id`() {
        let reference = HomebrewPackageID.formula(name: "zlib")
        let item = PackageRelationshipItem.dependency(
            reference,
            installedPackageIDs: [.formula(name: "openssl@3")],
        )

        #expect(item.installedPackageID == nil)
        #expect(!item.isInstalledInInventory)
        #expect(item.id == .formula(name: "zlib"))
    }

    @Test @MainActor func `dependencies maps each reference`() {
        let items = PackageRelationshipItem.dependencies(
            [.formula(name: "openssl@3"), .formula(name: "zlib")],
            installedPackageIDs: [.formula(name: "openssl@3")],
        )

        #expect(items.count == 2)
        #expect(items[0].isInstalledInInventory)
        #expect(!items[1].isInstalledInInventory)
    }

    @Test @MainActor func `dependent and dependents always mark installed`() {
        let package = InstalledBrewPackage.fixture(name: "curl", displayName: "cURL", kind: .formula)
        let dependent = PackageRelationshipItem.dependent(package)
        let dependents = PackageRelationshipItem.dependents([package])

        #expect(dependent.displayName == "cURL")
        #expect(dependent.installedPackageID == package.id)
        #expect(dependent.isInstalledInInventory)
        #expect(dependents.count == 1)
        #expect(dependents[0].displayName == "cURL")
        #expect(dependents[0].id == package.id)
    }
}
