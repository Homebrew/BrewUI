//
//  PackageUpgradeCommand.swift
//  Brew
//

import Foundation

/// Schedules `brew upgrade <name>` or `brew upgrade --cask <name>` via ``BrewCommandCenter/submit``.
struct PackageUpgradeCommand: BrewMutatingCommand {
    let packageName: String
    let kind: InstalledPackageKind

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
