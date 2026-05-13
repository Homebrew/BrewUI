//
//  OperationFailure.swift
//  Brew
//

import Foundation

/// User-visible and diagnostic failure surfaced through ``BrewOperationPhase/failed(reason:)`` (`Sendable` for actor-isolated state).
nonisolated enum OperationFailure: Equatable {
    /// `brew` ran but exited non-zero; stderr is the primary user-visible detail when present.
    case brewCommand(exitCode: Int32, stderr: String)

    /// Could not launch `brew` (POSIX / process spawn failure before exit status).
    case brewLaunchFailed(diagnostic: String)

    /// Locator could not find `brew` in supported prefixes (`AGENTS.md`).
    case brewExecutableNotFound

    /// Fallback for arbitrary errors: localized/user text plus optional diagnostic string.
    case generic(userFacing: String, diagnostic: String?)

    /// Primary line for UI and accessibility (derived per case).
    var userFacingMessage: String {
        switch self {
        case let .brewCommand(_, stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            return String(
                localized: "Homebrew command failed.",
                comment: "Shown when brew exits non-zero with no stderr",
            )

        case let .brewLaunchFailed(diagnostic):
            return diagnostic

        case .brewExecutableNotFound:
            return String(
                localized: "Could not find the brew executable.",
                comment: "Shown when brew binary is missing",
            )

        case let .generic(userFacing, _):
            return userFacing
        }
    }

    init(userFacingMessage: String, diagnosticDescription: String? = nil) {
        self = .generic(userFacing: userFacingMessage, diagnostic: diagnosticDescription)
    }

    init(catching error: Error) {
        switch error {
        case let brewCommandError as BrewCommandError:
            switch brewCommandError {
            case let .failed(exitCode, stderr):
                self = .brewCommand(exitCode: exitCode, stderr: stderr)
            case let .launchFailed(underlying):
                self = .brewLaunchFailed(diagnostic: underlying)
            }

        case BrewLookupError.executableNotFound:
            self = .brewExecutableNotFound

        default:
            let userFacing = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            self = .generic(userFacing: userFacing, diagnostic: String(describing: error))
        }
    }
}
