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

    /// The quit → replace → relaunch handoff that makes this safe to run lives above this layer.
    public static func selfUpgrade() -> BrewCommand {
        BrewCommand(
            operationKind: .upgradeApp,
            arguments: ["upgrade", "--cask", SelfUpgradeIdentity.caskToken],
        )
    }

    /// A `brew doctor` fix, e.g. `["link", "openssl@3"]` or `["cleanup"]` — the argv is the fix itself.
    public static func doctorFix(arguments: [String]) -> BrewCommand {
        BrewCommand(operationKind: .doctorFix, arguments: arguments)
    }

    /// `brew doctor` — read-only; run in capture mode so the repository gets its output back to strip + parse.
    public static func doctorRead() -> BrewCommand {
        BrewCommand(operationKind: .doctorRead, arguments: ["doctor"])
    }

    /// `--force` because the save panel has already confirmed replacing an existing file.
    public static func bundleDump(fileURL: URL) -> BrewCommand {
        BrewCommand(
            operationKind: .bundleDump,
            arguments: ["bundle", "dump", "--file=\(fileURL.path)", "--force"],
        )
    }

    /// `brew cleanup --dry-run`, captured so the Cleanup tab can list what a real run would remove.
    /// `pruneAll` adds `--prune=all`, which removes every cached download regardless of age.
    public static func cleanupPreview(pruneAll: Bool) -> BrewCommand {
        BrewCommand(operationKind: .cleanupPreview, arguments: cleanupArguments(dryRun: true, pruneAll: pruneAll))
    }

    /// `brew cleanup`, matching the ``cleanupPreview(pruneAll:)`` the user reviewed.
    public static func cleanup(pruneAll: Bool) -> BrewCommand {
        BrewCommand(operationKind: .cleanup, arguments: cleanupArguments(dryRun: false, pruneAll: pruneAll))
    }

    private static func cleanupArguments(dryRun: Bool, pruneAll: Bool) -> [String] {
        ["cleanup"] + (dryRun ? ["--dry-run"] : []) + (pruneAll ? ["--prune=all"] : [])
    }

    private static func flag(for kind: HomebrewPackageKind) -> String {
        kind == .formula ? "--formula" : "--cask"
    }
}
