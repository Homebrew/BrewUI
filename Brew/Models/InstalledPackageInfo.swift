//
//  InstalledPackageInfo.swift
//  Brew
//

import Foundation

/// One installed package entry hydrated from Homebrew output (formula or cask).
struct InstalledPackageInfo: Equatable, Hashable {
    var name: String
    var version: String?
}

/// Result of loading installed formulae and casks from Homebrew.
struct InstalledPackagesSnapshot: Equatable {
    var formulae: [InstalledPackageInfo]
    var casks: [InstalledPackageInfo]

    static let empty = InstalledPackagesSnapshot(formulae: [], casks: [])
}
