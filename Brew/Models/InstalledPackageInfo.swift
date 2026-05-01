//
//  InstalledPackageInfo.swift
//  Brew
//

import Foundation

/// One installed package entry hydrated from Homebrew output (formula or cask).
struct InstalledPackageInfo: Equatable, Hashable {
    var name: String
    var version: String?
    /// Raw stable / tap version string when Homebrew marks the package outdated (whitespace-trimmed; display formatting is a ViewModel concern).
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
