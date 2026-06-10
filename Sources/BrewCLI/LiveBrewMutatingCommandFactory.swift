//
//  LiveBrewMutatingCommandFactory.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Production factory vending the concrete `brew` command types from this module.
public struct LiveBrewMutatingCommandFactory: BrewMutatingCommandFactory {
    public init() {}

    public func installCommand(kind: HomebrewPackageKind, name: String) -> any BrewMutatingCommand {
        PackageInstallCommand(kind: kind, name: name)
    }

    public func upgradeCommand(kind: HomebrewPackageKind, name: String) -> any BrewMutatingCommand {
        PackageUpgradeCommand(kind: kind, name: name)
    }

    public func uninstallCommand(kind: HomebrewPackageKind, name: String) -> any BrewMutatingCommand {
        PackageUninstallCommand(kind: kind, name: name)
    }

    public func bulkUpgradeCommand() -> any BrewMutatingCommand {
        BulkUpgradeCommand()
    }

    public func doctorFixCommand(arguments: [String]) -> any BrewMutatingCommand {
        DoctorFixCommand(arguments: arguments)
    }
}
