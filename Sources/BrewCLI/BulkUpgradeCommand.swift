//
//  BulkUpgradeCommand.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Schedules a batch `brew upgrade` via ``BrewCommandCenter/submit`` for a ``BrewUpgradeSelection`` —
/// everything outdated, a single kind (`--formula`/`--cask`), or an explicit list of names. Homebrew runs
/// it in one subprocess, matching what a user would type in Terminal and the command rendered by the
/// Upgrades tab's command block.
///
/// Both the argument list and the human-readable rendering come from the same ``BrewUpgradeSelection``, so
/// what runs and what's shown can't drift.
struct BulkUpgradeCommand: BrewMutatingCommand {
    let selection: BrewUpgradeSelection

    var operationKind: BrewOperationKind {
        .upgradeAll
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        let brew = try context.brewExecutableURL()
        let output = try await context.commandRunner.run(
            executableURL: brew,
            arguments: selection.arguments,
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
