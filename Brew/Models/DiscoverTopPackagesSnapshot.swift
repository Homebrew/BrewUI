//
//  DiscoverTopPackagesSnapshot.swift
//  Brew
//

import Foundation

/// Domain output for Discover top package sections.
struct DiscoverTopPackagesSnapshot: Equatable {
    let topFormulae: [DiscoveryPackage]
    let topCasks: [DiscoveryPackage]
}

struct DiscoveryPackage: Equatable, Hashable {
    let package: BrewPackage
    let thirtyDayInstallCount: Int

    var reference: HomebrewPackageReference {
        package.reference
    }

    var name: String {
        reference.name
    }
}
