//
//  InstalledBrewPackage.swift
//  BrewCore
//

import Foundation

public nonisolated struct InstalledBrewPackage: Identifiable, Hashable {
    public var package: BrewPackage
    public var installedVersions: [String]
    public var outdated: Bool

    public var name: String {
        package.name
    }

    public var displayName: String {
        package.displayName
    }

    public var kind: HomebrewPackageKind {
        package.kind
    }

    public var description: String {
        get { package.description }
        set { package.description = newValue }
    }

    public var homepage: String {
        get { package.homepage }
        set { package.homepage = newValue }
    }

    public var latestVersion: String {
        get { package.latestVersion }
        set { package.latestVersion = newValue }
    }

    public var dependencies: [HomebrewPackageID] {
        get { package.dependencies }
        set { package.dependencies = newValue }
    }

    public var id: HomebrewPackageID {
        package.id
    }

    public var reference: HomebrewPackageID {
        HomebrewPackageID(package: package)
    }

    public init(package: BrewPackage, installedVersions: [String], outdated: Bool) {
        self.package = package
        self.installedVersions = installedVersions
        self.outdated = outdated
    }
}
