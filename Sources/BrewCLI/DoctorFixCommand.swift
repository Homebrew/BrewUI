//
//  DoctorFixCommand.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Schedules an arbitrary `brew` maintenance invocation (e.g. a `brew doctor` fix such as `brew link openssl@3`
/// or `brew cleanup`) via ``BrewCommandCenter/submit``, using ``BrewCommandExecutionContext`` for subprocess
/// execution and `brew` resolution.
///
/// Unlike the package commands this runs a caller-supplied argument vector, so it reports the generic
/// ``BrewOperationKind/doctorFix`` kind rather than a package-scoped one.
struct DoctorFixCommand: BrewMutatingCommand {
    let arguments: [String]

    var operationKind: BrewOperationKind {
        .doctorFix
    }

    func run(in context: BrewCommandExecutionContext) async throws {
        let brew = try context.brewExecutableURL()
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
