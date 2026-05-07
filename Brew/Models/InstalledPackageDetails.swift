//
//  InstalledPackageDetails.swift
//  Brew
//

import Foundation

/// Detailed package information for the Installed detail pane.
struct InstalledPackageDetails: Equatable {
    var name: String
    var kind: InstalledPackageKind
    var description: String?
    var version: String?
    var installedVersions: [String]
    var homepage: String?
    var dependencies: [String]
    var outdated: Bool
    var availableVersion: String?
}
