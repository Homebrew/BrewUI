//
//  PackageUpgradeCommand.swift
//  Brew
//

import Foundation

/// Schedules `brew upgrade <name>` or `brew upgrade --cask <name>` via ``BrewCommandCenter/submit``,
/// using ``BrewCommandExecutionContext`` for subprocess execution and `brew` resolution.
///
/// Pair with ``BrewOperationID/init(row:)`` so the command center’s operation id matches the
/// `kind:name` identity in ``InstalledPackageRow/id``.
struct PackageUpgradeCommand: BrewMutatingCommand {
    let packageName: String
    let kind: InstalledPackageKind

    /// Upgrade the package identified by the list row; same name/kind as ``InstalledPackageRow/id``.
    init(row: InstalledPackageRow) {
        packageName = row.name
        kind = row.kind
    }

    init(kind: InstalledPackageKind, name: String) {
        packageName = name
        self.kind = kind
    }

    nonisolated var operationKind: BrewOperationKind {
        switch kind {
        case .formula:
            .upgradeFormula
        case .cask:
            .upgradeCask
        }
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        let brew = try context.brewExecutableURL()
        let arguments: [String] = switch kind {
        case .formula:
            ["upgrade", packageName]
        case .cask:
            ["upgrade", "--cask", packageName]
        }

        let output = try await context.commandRunner.run(
            executableURL: brew,
            arguments: arguments,
        )
        guard output.terminationStatus == 0 else {
            throw BrewCommandError.failed(
                exitCode: output.terminationStatus,
                stderr: output.standardError,
            )
        }
    }
}
