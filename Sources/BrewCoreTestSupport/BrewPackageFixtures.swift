//
//  BrewPackageFixtures.swift
//  BrewCoreTestSupport
//

import BrewCore
import Foundation

public nonisolated extension BrewPackage {
    static func fixture(
        name: String = "git",
        displayName: String? = nil,
        kind: HomebrewPackageKind = .formula,
        description: String = "",
        homepage: String = "",
        latestVersion: String = "",
        dependencies: [HomebrewPackageID] = [],
    ) -> BrewPackage {
        BrewPackage(
            name: name,
            displayName: displayName ?? name,
            kind: kind,
            description: description,
            homepage: homepage,
            latestVersion: latestVersion,
            dependencies: dependencies,
        )
    }
}

public extension [BrewPackage] {
    static var empty: [BrewPackage] {
        []
    }
}

public nonisolated extension InstalledBrewPackage {
    static func fixture(
        name: String = "git",
        displayName: String? = nil,
        kind: HomebrewPackageKind = .formula,
        description: String = "",
        homepage: String = "",
        latestVersion: String = "",
        installedVersions: [String] = [],
        dependencies: [HomebrewPackageID] = [],
        outdated: Bool = false,
    ) -> InstalledBrewPackage {
        InstalledBrewPackage(
            package: .fixture(
                name: name,
                displayName: displayName,
                kind: kind,
                description: description,
                homepage: homepage,
                latestVersion: latestVersion,
                dependencies: dependencies,
            ),
            installedVersions: installedVersions,
            outdated: outdated,
        )
    }
}

public extension [InstalledBrewPackage] {
    static var empty: [InstalledBrewPackage] {
        []
    }
}
