//
//  BrewCommands.swift
//  BrewCore
//

import Foundation

/// Pure builders for the ``BrewCommand`` values the app schedules. Keeping argv construction here (rather than
/// in per-command types) means "what runs" and "what phase/console kind it shows as" are defined together, in
/// one place, as data.
public enum BrewCommands {
    public static func install(_ name: String, kind: HomebrewPackageKind) -> BrewCommand {
        BrewCommand(
            operationKind: kind == .formula ? .installFormula : .installCask,
            arguments: ["install", flag(for: kind), name],
        )
    }

    public static func upgrade(_ name: String, kind: HomebrewPackageKind) -> BrewCommand {
        BrewCommand(
            operationKind: kind == .formula ? .upgradeFormula : .upgradeCask,
            arguments: ["upgrade", flag(for: kind), name],
        )
    }

    public static func uninstall(_ name: String, kind: HomebrewPackageKind) -> BrewCommand {
        BrewCommand(
            operationKind: kind == .formula ? .uninstallFormula : .uninstallCask,
            arguments: ["uninstall", flag(for: kind), name],
        )
    }

    /// Batch `brew upgrade` for the given selection — everything outdated, a single kind, or an explicit list.
    public static func bulkUpgrade(_ selection: BrewUpgradeSelection) -> BrewCommand {
        BrewCommand(operationKind: .upgradeAll, arguments: selection.arguments)
    }

    /// A `brew doctor` fix, e.g. `["link", "openssl@3"]` or `["cleanup"]` — the argv is the fix itself.
    public static func doctorFix(arguments: [String]) -> BrewCommand {
        BrewCommand(operationKind: .doctorFix, arguments: arguments)
    }

    /// `brew doctor` — read-only; its output is parsed, so it is run in capture mode (no forced colour).
    public static func doctorRead() -> BrewCommand {
        BrewCommand(operationKind: .doctorRead, arguments: ["doctor"])
    }

    private static func flag(for kind: HomebrewPackageKind) -> String {
        kind == .formula ? "--formula" : "--cask"
    }
}
