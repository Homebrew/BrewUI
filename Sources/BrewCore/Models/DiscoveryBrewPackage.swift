//
//  DiscoveryBrewPackage.swift
//  BrewCore
//

import Foundation

/// Domain output for Discover top package sections.
public struct DiscoverTopPackagesSnapshot: Equatable, Sendable {
    public let topFormulae: [DiscoveryBrewPackage]
    public let topCasks: [DiscoveryBrewPackage]

    public init(topFormulae: [DiscoveryBrewPackage], topCasks: [DiscoveryBrewPackage]) {
        self.topFormulae = topFormulae
        self.topCasks = topCasks
    }
}

public struct DiscoveryBrewPackage: Identifiable, Equatable, Hashable, Sendable {
    public var package: BrewPackage
    public var thirtyDayInstallCount: Int

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

    public init(package: BrewPackage, thirtyDayInstallCount: Int) {
        self.package = package
        self.thirtyDayInstallCount = thirtyDayInstallCount
    }
}
