//
//  BrewUpgradeSelection.swift
//  BrewCore
//

import Foundation

/// What a single "Upgrade All" submission actually upgrades. The Upgrades tab derives this from its
/// active scope picker and search field so the batch operation matches the visible list:
///
/// - ``all`` — `brew upgrade` (every outdated formula and cask).
/// - ``formulae`` — `brew upgrade --formula` (every outdated formula).
/// - ``casks`` — `brew upgrade --cask` (every outdated cask).
/// - ``explicit(_:)`` — `brew upgrade <name>…` for a specific set of packages (used when a search
///   narrows the list to named rows).
///
/// It is the single source of truth for both the argument vector the subprocess runs (``arguments``)
/// and the user-facing command string rendered in the header and console (``displayCommand``), so the
/// two can never drift.
public enum BrewUpgradeSelection: Hashable, Sendable {
    case all
    case formulae
    case casks
    case explicit([String])

    /// Argument vector passed to the `brew` executable.
    public var arguments: [String] {
        switch self {
        case .all:
            ["upgrade"]
        case .formulae:
            ["upgrade", "--formula"]
        case .casks:
            ["upgrade", "--cask"]
        case let .explicit(names):
            ["upgrade"] + names
        }
    }

    /// The literal a person would type — `"brew "` joined with ``arguments``.
    public var displayCommand: String {
        "brew " + arguments.joined(separator: " ")
    }
}
