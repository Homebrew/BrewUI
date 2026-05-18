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
    var installedVersions: [String]
    var dependencies: [HomebrewPackageReference]
    var outdated: Bool

    var id: String {
        "\(kind.rawValue):\(name)"
    }
}
