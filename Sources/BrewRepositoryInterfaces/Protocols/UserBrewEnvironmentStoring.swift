//
//  UserBrewEnvironmentStoring.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

/// Reads and writes the user-scope Homebrew environment file (`~/.homebrew/brew.env`).
///
/// Homebrew loads this file itself on every `brew` process, so the app only needs to maintain the
/// proxy keys; it never injects them into the isolated command environment.
public protocol UserBrewEnvironmentStoring: Sendable {
    /// Proxy settings currently declared in the user file. Missing keys read as empty.
    func loadProxySettings() throws -> BrewProxySettings

    /// Replaces the managed proxy keys and leaves every other line untouched.
    /// Manual mode writes empty values for unused proxy keys to override inherited settings.
    /// Removing user settings deletes the keys, allowing installation and system defaults to apply.
    func saveProxySettings(_ settings: BrewProxySettings) throws
}

/// Failures from reading or writing the user `brew.env` file.
public enum UserBrewEnvironmentError: Error, Equatable, Sendable {
    case unreadable(path: String)
    case unwritable(path: String)
    case rejectedValue(field: BrewProxySettings.Field)
}
