//
//  BrewCommandError.swift
//  Brew
//

import Foundation

/// `brew` exited non-zero or could not be launched.
nonisolated enum BrewCommandError: Error, Equatable {
    case failed(exitCode: Int32, stderr: String)
    case launchFailed(underlying: String)
}
