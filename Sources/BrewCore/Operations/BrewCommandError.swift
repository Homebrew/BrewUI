//
//  BrewCommandError.swift
//  BrewCore
//

import Foundation

/// `brew` exited non-zero or could not be launched.
public nonisolated enum BrewCommandError: Error, Equatable, Sendable {
    case failed(exitCode: Int32, stderr: String)
    case launchFailed(underlying: String)
}
