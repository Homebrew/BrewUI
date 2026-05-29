//
//  PackageDependencyGraph.swift
//  BrewCore
//

import Foundation

/// Reverse dependency lookups over one installed-inventory snapshot.
public struct PackageDependencyGraph: Equatable, Sendable {
    private let packagesByID: [InstalledBrewPackage.ID: InstalledBrewPackage]
    private let dependentsByDependencyPackageID: [InstalledBrewPackage.ID: [InstalledBrewPackage.ID]]

    public init(packages: [InstalledBrewPackage]) {
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

    public func installedDependents(for packageID: InstalledBrewPackage.ID) -> [InstalledBrewPackage] {
        (dependentsByDependencyPackageID[packageID] ?? [])
            .compactMap { packagesByID[$0] }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }
}
