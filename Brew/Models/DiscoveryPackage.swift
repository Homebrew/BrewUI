//
//  DiscoveryPackage.swift
//  Brew
//

import Foundation

/// Domain output for Discover top package sections.
struct DiscoverTopPackagesSnapshot: Equatable {
    let topFormulae: [DiscoveryPackage]
    let topCasks: [DiscoveryPackage]
}

struct DiscoveryPackage: Identifiable, Equatable, Hashable {
    var package: BrewPackage
    var thirtyDayInstallCount: Int

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
