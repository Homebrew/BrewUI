//
//  BrewPackage.swift
//  Brew
//

import Foundation

struct BrewPackage: Identifiable, Hashable {
    let name: String
    let displayName: String
    let kind: HomebrewPackageKind
    var description: String
    var homepage: String
    var latestVersion: String
    var dependencies: [HomebrewPackageReference]

    var id: String {
        "\(kind.rawValue):\(name)"
    }

    var reference: HomebrewPackageReference {
        HomebrewPackageReference(package: self)
    }
}
