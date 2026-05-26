//
//  HomebrewPackageKind.swift
//  Brew
//

import Foundation

/// Whether an installed Homebrew unit is a formula or a cask — domain-level discriminator (repositories, operations, presentation).
nonisolated enum HomebrewPackageKind: String, Hashable {
    case formula
    case cask
}

/// Stable synonym used across the Installed feature and tests — identical to ``HomebrewPackageKind``.
typealias InstalledPackageKind = HomebrewPackageKind
