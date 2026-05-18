//
//  PackageRelationshipItem.swift
//  Brew
//

import Foundation

/// One dependency or dependent row in installed package detail.
struct PackageRelationshipItem: Identifiable, Hashable {
    let displayName: String
    let packageKind: HomebrewPackageKind
    let targetPackageID: BrewPackage.ID
    let installedPackageID: BrewPackage.ID?

    var id: String {
        installedPackageID ?? "relationship:\(targetPackageID)"
    }

    var isInstalledInInventory: Bool {
        installedPackageID != nil
    }
}

@MainActor
extension PackageRelationshipItem {
    static func dependency(
        _ reference: HomebrewPackageReference,
        installedPackageIDs: Set<BrewPackage.ID>,
    ) -> PackageRelationshipItem {
        PackageRelationshipItem(
            displayName: reference.name,
            packageKind: reference.kind,
            targetPackageID: reference.packageID,
            installedPackageID: installedPackageIDs.contains(reference.packageID) ? reference.packageID : nil,
        )
    }

    static func dependent(_ package: BrewPackage) -> PackageRelationshipItem {
        PackageRelationshipItem(
            displayName: package.displayName,
            packageKind: package.kind,
            targetPackageID: package.id,
            installedPackageID: package.id,
        )
    }

    static func dependencies(
        _ references: [HomebrewPackageReference],
        installedPackageIDs: Set<BrewPackage.ID>,
    ) -> [PackageRelationshipItem] {
        references.map { dependency($0, installedPackageIDs: installedPackageIDs) }
    }

    static func dependents(_ packages: [BrewPackage]) -> [PackageRelationshipItem] {
        packages.map(dependent)
    }
}
