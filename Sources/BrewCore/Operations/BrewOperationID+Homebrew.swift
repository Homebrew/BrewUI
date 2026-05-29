//
//  BrewOperationID+Homebrew.swift
//  BrewCore
//

import Foundation

public extension BrewOperationID {
    /// Operation identity from a domain package kind + name.
    init(kind: HomebrewPackageKind, name: String) {
        switch kind {
        case .formula:
            self.init(packageID: .formula(name: name))
        case .cask:
            self.init(packageID: .cask(token: name))
        }
    }

    init(package: InstalledBrewPackage) {
        self.init(packageID: HomebrewPackageID(installedPackage: package))
    }
}
