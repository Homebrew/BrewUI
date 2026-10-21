//
//  RepositoryError.swift
//  BrewRepositoryInterfaces
//

/// Failures a repository raises that are not `brew` exit codes or launch errors.
public enum BrewRepositoryError: Error, Equatable, Sendable {
    case malformedBrewOutput(command: String)
    /// The installed Homebrew has no such command, e.g. `brew vulns` before Homebrew 7.0.
    case unsupportedBrewCommand(command: String)
}
