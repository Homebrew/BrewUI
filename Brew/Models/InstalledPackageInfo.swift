//
//  InstalledPackageInfo.swift
//  Brew
//

import Foundation

/// One installed package entry hydrated from Homebrew output (formula or cask).
struct InstalledPackageInfo: Equatable, Hashable {
    var name: String
    var version: String?
    /// Formatted upgrade target when Homebrew marks the package outdated and a stable/tap version is known.
    var upgradeToVersion: String?

    init(name: String, version: String?, upgradeToVersion: String? = nil) {
        self.name = name
        self.version = version
        self.upgradeToVersion = upgradeToVersion
    }
}

/// Result of loading installed formulae and casks from Homebrew.
struct InstalledPackagesSnapshot: Equatable {
    var formulae: [InstalledPackageInfo]
    var casks: [InstalledPackageInfo]

    static let empty = InstalledPackagesSnapshot(formulae: [], casks: [])
}
