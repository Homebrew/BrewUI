//
//  RepositoryError.swift
//  BrewRepositoryInterfaces
//

/// Failures a repository raises that are not `brew` exit codes or launch errors.
public enum BrewRepositoryError: Error, Equatable, Sendable {
    case malformedBrewOutput(command: String)
}
