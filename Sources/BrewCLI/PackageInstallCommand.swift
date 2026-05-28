//
//  PackageInstallCommand.swift
//  Brew
//

import BrewCore
import Foundation

/// Schedules `brew install <name>` or `brew install --cask <name>` via ``BrewCommandCenter/submit``,
/// using ``BrewCommandExecutionContext`` for subprocess execution and `brew` resolution.
///
public nonisolated struct PackageInstallCommand: BrewMutatingCommand {
    let packageName: String
    let kind: InstalledPackageKind

    public init(package: DiscoveryBrewPackage) {
        packageName = package.name
        kind = package.kind
    }

    public init(kind: InstalledPackageKind, name: String) {
        packageName = name
        self.kind = kind
    }

    public nonisolated var operationKind: BrewOperationKind {
        switch kind {
        case .formula:
            .installFormula
        case .cask:
            .installCask
        }
    }

    public func run(in context: BrewCommandExecutionContext) async throws {
        let brew = try context.brewExecutableURL()
        let arguments: [String] = switch kind {
        case .formula:
            ["install", "--formula", packageName]
        case .cask:
            ["install", "--cask", packageName]
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
