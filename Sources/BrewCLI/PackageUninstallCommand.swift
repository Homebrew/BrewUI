//
//  PackageUninstallCommand.swift
//  Brew
//
import BrewCore
import Foundation

/// Schedules `brew uninstall <name>` or `brew uninstall --cask <name>` via ``BrewCommandCenter/submit``,
/// using ``BrewCommandExecutionContext`` for subprocess execution and `brew` resolution.
nonisolated struct PackageUninstallCommand: BrewMutatingCommand {
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

    nonisolated var operationKind: BrewOperationKind {
        switch kind {
        case .formula:
            .uninstallFormula
        case .cask:
            .uninstallCask
        }
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        let brew = try context.brewExecutableURL()
        let arguments: [String] = switch kind {
        case .formula:
            ["uninstall", "--formula", packageName]
        case .cask:
            ["uninstall", "--cask", packageName]
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
