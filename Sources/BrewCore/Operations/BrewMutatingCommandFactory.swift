//
//  BrewMutatingCommandFactory.swift
//  BrewCore
//

import Foundation

/// Builds concrete ``BrewMutatingCommand`` values without exposing their types to callers.
///
/// View models depend on this port (an abstraction over `BrewCore` value types) rather than importing
/// the concrete command types in `BrewCLI`, then hand the result to ``BrewCommandCenter/submit(id:command:)``.
public protocol BrewMutatingCommandFactory: Sendable {
    func installCommand(kind: HomebrewPackageKind, name: String) -> any BrewMutatingCommand
    func upgradeCommand(kind: HomebrewPackageKind, name: String) -> any BrewMutatingCommand
    func uninstallCommand(kind: HomebrewPackageKind, name: String) -> any BrewMutatingCommand

    /// Builds the bulk `brew upgrade` command — invoked with no arguments so Homebrew upgrades every
    /// outdated formula and cask in a single subprocess. Submitted under ``BrewOperationID/bulkUpgrade``.
    func bulkUpgradeCommand() -> any BrewMutatingCommand

    /// Builds a maintenance command running the given `brew` argument vector (e.g. a `brew doctor` fix
    /// like `["link", "openssl@3"]` or `["cleanup"]`). Not package-scoped — surfaces in the console as
    /// a ``BrewOperationKind/doctorFix`` operation.
    func doctorFixCommand(arguments: [String]) -> any BrewMutatingCommand
}
