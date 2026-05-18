//
//  DiscoverTopPackagesSnapshot.swift
//  Brew
//

import Foundation

/// Domain output for Discover top package sections.
struct DiscoverTopPackagesSnapshot: Equatable {
    let topFormulae: [DiscoverTopPackage]
    let topCasks: [DiscoverTopPackage]
}

struct DiscoverTopPackage: Equatable, Hashable {
    let reference: HomebrewPackageReference
    let installCount: Int

    var name: String {
        reference.name
    }
}
