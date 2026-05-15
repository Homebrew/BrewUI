//
//  PackageDependencyGraph.swift
//  Brew
//

import Foundation

/// Reverse dependency lookups over one installed-inventory snapshot.
struct PackageDependencyGraph: Equatable {
    private let packagesByID: [BrewPackage.ID: BrewPackage]
    private let dependentsByDependencyPackageID: [BrewPackage.ID: [BrewPackage.ID]]

    init(packages: [BrewPackage]) {
        var byID: [BrewPackage.ID: BrewPackage] = [:]
        var reverse: [BrewPackage.ID: [BrewPackage.ID]] = [:]

        for package in packages {
            byID[package.id] = package
            for dependency in package.dependencies {
                reverse[dependency.packageID, default: []].append(package.id)
            }
        }

        packagesByID = byID
        dependentsByDependencyPackageID = reverse
    }

    func installedDependents(for packageID: BrewPackage.ID) -> [BrewPackage] {
        (dependentsByDependencyPackageID[packageID] ?? [])
            .compactMap { packagesByID[$0] }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }
}
