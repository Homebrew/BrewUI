//
//  PackageRelationshipItem.swift
//  Brew
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation

/// One dependency or dependent row in installed package detail.
struct PackageRelationshipItem: Identifiable, Hashable {
    let displayName: String
    let packageKind: HomebrewPackageKind
    let targetPackageID: InstalledBrewPackage.ID
    let installedPackageID: InstalledBrewPackage.ID?

    var id: HomebrewPackageID {
        targetPackageID
    }

    var isInstalledInInventory: Bool {
        installedPackageID != nil
    }
}

@MainActor
extension PackageRelationshipItem {
    static func dependency(
        _ reference: HomebrewPackageID,
        installedPackageIDs: Set<InstalledBrewPackage.ID>,
    ) -> PackageRelationshipItem {
        PackageRelationshipItem(
            displayName: reference.name,
            packageKind: reference.kind,
            targetPackageID: reference,
            installedPackageID: installedPackageIDs.contains(reference) ? reference : nil,
        )
    }

    static func dependent(_ package: InstalledBrewPackage) -> PackageRelationshipItem {
        PackageRelationshipItem(
            displayName: package.displayName,
            packageKind: package.kind,
            targetPackageID: package.id,
            installedPackageID: package.id,
        )
    }

    static func dependencies(
        _ references: [HomebrewPackageID],
        installedPackageIDs: Set<InstalledBrewPackage.ID>,
    ) -> [PackageRelationshipItem] {
        references.map { dependency($0, installedPackageIDs: installedPackageIDs) }
    }

    static func dependents(_ packages: [InstalledBrewPackage]) -> [PackageRelationshipItem] {
        packages.map(dependent)
    }
}
