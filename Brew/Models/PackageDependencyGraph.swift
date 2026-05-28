//
//  PackageDependencyGraph.swift
//  Brew
//

import Foundation

/// Reverse dependency lookups over one installed-inventory snapshot.
nonisolated struct PackageDependencyGraph: Equatable {
    private let packagesByID: [InstalledBrewPackage.ID: InstalledBrewPackage]
    private let dependentsByDependencyPackageID: [InstalledBrewPackage.ID: [InstalledBrewPackage.ID]]

    init(packages: [InstalledBrewPackage]) {
        var byID: [InstalledBrewPackage.ID: InstalledBrewPackage] = [:]
        var reverse: [InstalledBrewPackage.ID: [InstalledBrewPackage.ID]] = [:]

        for package in packages {
            byID[package.id] = package
            for dependency in package.dependencies {
                reverse[dependency, default: []].append(package.id)
            }
        }

        packagesByID = byID
        dependentsByDependencyPackageID = reverse
    }

    func installedDependents(for packageID: InstalledBrewPackage.ID) -> [InstalledBrewPackage] {
        (dependentsByDependencyPackageID[packageID] ?? [])
            .compactMap { packagesByID[$0] }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }
}
