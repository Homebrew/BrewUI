//
//  BrewPackage.swift
//  BrewCore
//

import Foundation

public nonisolated struct BrewPackage: Identifiable, Hashable, Sendable {
    public let name: String
    public let displayName: String
    public let kind: HomebrewPackageKind
    public var description: String
    public var homepage: String
    public var latestVersion: String
    public var dependencies: [HomebrewPackageID]

    public var id: HomebrewPackageID {
        reference
    }

    public var reference: HomebrewPackageID {
        HomebrewPackageID(package: self)
    }

    public init(
        name: String,
        displayName: String,
        kind: HomebrewPackageKind,
        description: String,
        homepage: String,
        latestVersion: String,
        dependencies: [HomebrewPackageID],
    ) {
        self.name = name
        self.displayName = displayName
        self.kind = kind
        self.description = description
        self.homepage = homepage
        self.latestVersion = latestVersion
        self.dependencies = dependencies
    }
}
