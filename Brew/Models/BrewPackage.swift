//
//  BrewPackage.swift
//  Brew
//

import Foundation

nonisolated struct BrewPackage: Identifiable, Hashable {
    let name: String
    let displayName: String
    let kind: HomebrewPackageKind
    var description: String
    var homepage: String
    var latestVersion: String
    var dependencies: [HomebrewPackageID]

    var id: HomebrewPackageID {
        reference
    }

    var reference: HomebrewPackageID {
        HomebrewPackageID(package: self)
    }
}
