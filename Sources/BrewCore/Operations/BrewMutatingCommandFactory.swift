//
//  BrewMutatingCommandFactory.swift
//  BrewCore
//

import Foundation

/// Builds the ``BrewCommand`` values view models hand to ``BrewCommandCenter``.
///
/// A thin port over ``BrewCommands`` so view models can be constructed with a stub in previews/tests without
/// wiring a real command center. Production uses ``LiveBrewMutatingCommandFactory``.
public protocol BrewMutatingCommandFactory: Sendable {
    func installCommand(kind: HomebrewPackageKind, name: String) -> BrewCommand
    func upgradeCommand(kind: HomebrewPackageKind, name: String) -> BrewCommand
    func uninstallCommand(kind: HomebrewPackageKind, name: String) -> BrewCommand

    /// Builds a batch `brew upgrade` command for the given ``BrewUpgradeSelection`` — either everything
    /// outdated, a single kind (`--formula`/`--cask`), or an explicit list of names.
    func bulkUpgradeCommand(selection: BrewUpgradeSelection) -> BrewCommand

    /// Builds a maintenance command running the given `brew` argument vector (e.g. a `brew doctor` fix
    /// like `["link", "openssl@3"]` or `["cleanup"]`).
    func doctorFixCommand(arguments: [String]) -> BrewCommand
}
