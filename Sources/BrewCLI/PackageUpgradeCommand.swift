//
//  PackageUpgradeCommand.swift
//  Brew
//

import BrewCore
import Foundation

/// Schedules `brew upgrade <name>` or `brew upgrade --cask <name>` via ``BrewCommandCenter/submit``,
/// using ``BrewCommandExecutionContext`` for subprocess execution and `brew` resolution.
///
struct PackageUpgradeCommand: BrewMutatingCommand {
    let packageName: String
    let kind: InstalledPackageKind

    init(package: InstalledBrewPackage) {
        packageName = package.name
        kind = package.kind
    }

    init(kind: InstalledPackageKind, name: String) {
        packageName = name
        self.kind = kind
    }

    var operationKind: BrewOperationKind {
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
            ["upgrade", "--formula", packageName]
        case .cask:
            ["upgrade", "--cask", packageName]
        }

        let output = try await context.commandRunner.run(
            executableURL: brew,
            arguments: arguments,
            console: context.console,
        )
        guard output.terminationStatus == 0 else {
            throw BrewCommandError.failed(
                exitCode: output.terminationStatus,
                stderr: output.standardError,
            )
        }
    }
}
