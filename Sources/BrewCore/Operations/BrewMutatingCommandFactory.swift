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
}
