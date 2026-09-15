//
//  RepositoryError.swift
//  BrewRepositoryInterfaces
//

/// Failures a repository raises that are not `brew` exit codes or launch errors.
public enum BrewRepositoryError: Error, Equatable, Sendable {
    /// `brew` succeeded but its output could not be decoded.
    case malformedBrewOutput(command: String)
}
