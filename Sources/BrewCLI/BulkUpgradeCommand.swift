//
//  BulkUpgradeCommand.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Schedules a single `brew upgrade` (no arguments) via ``BrewCommandCenter/submit``. Homebrew upgrades
/// every outdated formula and cask in one subprocess, matching what a user would type in Terminal and
/// the user-facing command rendered by the Upgrades tab's command block.
///
/// Keep this argument list in sync with ``BrewOperationID/bulkUpgradeDisplayCommand`` — the latter is the
/// human-readable rendering and must describe what this command actually runs.
struct BulkUpgradeCommand: BrewMutatingCommand {
    var operationKind: BrewOperationKind {
        .upgradeAll
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        let brew = try context.brewExecutableURL()
        let output = try await context.commandRunner.run(
            executableURL: brew,
            arguments: ["upgrade"],
        )
        guard output.terminationStatus == 0 else {
            throw BrewCommandError.failed(
                exitCode: output.terminationStatus,
                stderr: output.standardError,
            )
        }
    }
}
