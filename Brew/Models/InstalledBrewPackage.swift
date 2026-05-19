//
//  InstalledBrewPackage.swift
//  Brew
//

import Foundation

struct InstalledBrewPackage: Identifiable, Hashable {
    var package: BrewPackage
    var installedVersions: [String]
    var outdated: Bool

    var name: String {
        package.name
    }

    var displayName: String {
        package.displayName
    }

    var kind: HomebrewPackageKind {
        package.kind
    }

    var description: String {
        get { package.description }
        set { package.description = newValue }
    }

    var homepage: String {
        get { package.homepage }
        set { package.homepage = newValue }
    }

    var latestVersion: String {
        get { package.latestVersion }
        set { package.latestVersion = newValue }
    }

    var dependencies: [HomebrewPackageReference] {
        get { package.dependencies }
        set { package.dependencies = newValue }
    }

    var id: String {
        package.id
    }

    var reference: HomebrewPackageReference {
        HomebrewPackageReference(package: package)
    }
}
