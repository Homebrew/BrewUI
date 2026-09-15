//
//  BrewErrorCopy.swift
//  BrewUIComponents
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation

/// Words the typed errors thrown by the core and repository layers. The only place those
/// enums become user-facing text.
public nonisolated enum BrewErrorCopy {
    /// One line for any error the app surfaces; `fallback` is the feature's own generic line.
    public static func message(for error: any Error, fallback: String) -> String {
        switch error {
        case BrewLookupError.executableNotFound:
            brewNotFound
        case let BrewCommandError.failed(_, stderr):
            stderrOrGenericFailure(stderr)
        case let BrewCommandError.launchFailed(underlying):
            underlying
        case BrewRepositoryError.malformedBrewOutput:
            String(
                localized: "Homebrew returned output the app couldn’t read.",
                bundle: #bundle,
                comment: "Error when brew succeeded but its JSON output failed to decode",
            )
        default:
            fallback
        }
    }

    public static func message(for failure: OperationFailure) -> String {
        switch failure {
        case let .brewCommand(_, stderr):
            stderrOrGenericFailure(stderr)
        case let .brewLaunchFailed(diagnostic):
            diagnostic
        case .brewExecutableNotFound:
            brewNotFound
        case let .other(description, _):
            description
        }
    }

    private static var brewNotFound: String {
        String(
            localized: "Could not find Homebrew. Install it or ensure brew is in the default location.",
            bundle: #bundle,
            comment: "Error when the brew executable is not in either default prefix",
        )
    }

    private static func stderrOrGenericFailure(_ stderr: String) -> String {
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return String(
            localized: "Homebrew command failed.",
            bundle: #bundle,
            comment: "Error when brew exits non-zero without printing anything to stderr",
        )
    }
}
