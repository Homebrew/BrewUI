//
//  BrewOperationID+Homebrew.swift
//  Brew
//

import Foundation

nonisolated extension BrewOperationID {
    /// Operation identity from a domain package kind + name.
    init(kind: HomebrewPackageKind, name: String) {
        switch kind {
        case .formula:
            packageID = .formula(name: name)
        case .cask:
            packageID = .cask(token: name)
        }
    }

    init(package: InstalledBrewPackage) {
        packageID = HomebrewPackageID(installedPackage: package)
    }
}
