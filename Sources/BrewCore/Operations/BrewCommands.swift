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

    /// Uses native restart only for loaded, running jobs with no schedule, a positive PID and login
    /// registration enabled. Other restarts stop separately so callers can verify the stop before using
    /// `run` or `start` to preserve the original login registration.
    public static func service(_ action: BrewServiceAction, for service: BrewService) -> [BrewCommand] {
        let stop = BrewCommand(operationKind: .serviceControl, arguments: ["services", "stop", "--keep", service.name])
        if action == .stop { return [stop] }
        guard let registered = service.registered else { return [] }
        if action == .restart, registered, service.loaded == true, service.running, service.schedulable == false, (service.pid ?? 0) > 0 {
            return [BrewCommand(operationKind: .serviceControl, arguments: ["services", "restart", service.name])]
        }
        let start = BrewCommand(operationKind: .serviceControl, arguments: ["services", registered ? "start" : "run", service.name])
        if action == .restart || service.loaded == true || service.running { return [stop, start] }
        return [start]
    }

    private static func flag(for kind: HomebrewPackageKind) -> String {
        kind == .formula ? "--formula" : "--cask"
    }
}
