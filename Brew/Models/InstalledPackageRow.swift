//
//  InstalledPackageRow.swift
//  Brew
//

import Foundation

/// Homebrew package kind for installed list presentation.
enum InstalledPackageKind: String, Hashable {
    case formula
    case cask
}

/// One row in the Installed list (presentation model; map from domain later).
struct InstalledPackageRow: Identifiable, Hashable {
    let id: UUID
    var name: String
    var kind: InstalledPackageKind
    var description: String
    /// Installed version label, e.g. `v2.45.0`.
    var installedVersion: String
    /// When set, show update affordance (current → new).
    var updateVersion: String?

    init(
        id: UUID = UUID(),
        name: String,
        kind: InstalledPackageKind,
        description: String,
        installedVersion: String,
        updateVersion: String? = nil,
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.description = description
        self.installedVersion = installedVersion
        self.updateVersion = updateVersion
    }
}
