//
//  OperationFailure.swift
//  BrewCore
//

import Foundation

/// Why a command-center operation failed, surfaced through ``BrewOperationPhase/failed(reason:)``.
public enum OperationFailure: Equatable, Sendable {
    /// `brew` ran but exited non-zero; stderr is the primary user-visible detail when present.
    case brewCommand(exitCode: Int32, stderr: String)

    /// Could not launch `brew` (POSIX / process spawn failure before exit status).
    case brewLaunchFailed(diagnostic: String)

    /// Locator could not find `brew` in supported prefixes (`AGENTS.md`).
    case brewExecutableNotFound

    /// Any other error: its `localizedDescription` plus the full `String(describing:)` for logs.
    case other(description: String, diagnostic: String?)

    public init(description: String, diagnostic: String? = nil) {
        self = .other(description: description, diagnostic: diagnostic)
    }

    public init(catching error: Error) {
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
            let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            self = .other(description: description, diagnostic: String(describing: error))
        }
    }
}
