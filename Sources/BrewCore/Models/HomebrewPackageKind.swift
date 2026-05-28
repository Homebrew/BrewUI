//
//  HomebrewPackageKind.swift
//  BrewCore
//

import Foundation

/// Whether an installed Homebrew unit is a formula or a cask — domain-level discriminator (repositories, operations, presentation).
public nonisolated enum HomebrewPackageKind: String, Hashable, Sendable {
    case formula
    case cask
}

/// Stable synonym used across the Installed feature and tests — identical to ``HomebrewPackageKind``.
public typealias InstalledPackageKind = HomebrewPackageKind
