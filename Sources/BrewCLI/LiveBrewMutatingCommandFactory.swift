//
//  LiveBrewMutatingCommandFactory.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Production factory: a thin adapter over ``BrewCommands`` value builders.
public struct LiveBrewMutatingCommandFactory: BrewMutatingCommandFactory {
    public init() {}

    public func installCommand(kind: HomebrewPackageKind, name: String) -> BrewCommand {
        BrewCommands.install(name, kind: kind)
    }

    public func upgradeCommand(kind: HomebrewPackageKind, name: String) -> BrewCommand {
        BrewCommands.upgrade(name, kind: kind)
    }

    public func uninstallCommand(kind: HomebrewPackageKind, name: String) -> BrewCommand {
        BrewCommands.uninstall(name, kind: kind)
    }

    public func bulkUpgradeCommand(selection: BrewUpgradeSelection) -> BrewCommand {
        BrewCommands.bulkUpgrade(selection)
    }

    public func doctorFixCommand(arguments: [String]) -> BrewCommand {
        BrewCommands.doctorFix(arguments: arguments)
    }
}
