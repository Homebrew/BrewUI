//
//  HomebrewEnvironmentReading.swift
//  BrewCore
//

import Foundation

/// Reads the Homebrew environment as `brew` itself resolves it.
///
/// `ProcessInfo` is no substitute: the app is launched by Finder, not from the user's shell, so a
/// `HOMEBREW_*` variable exported in a shell profile is invisible to the app's own environment while
/// being fully in effect for every `brew` invocation the app makes through the login shell.
public protocol HomebrewEnvironmentReading: Sendable {
    /// True when `HOMEBREW_NO_INSTALL_FROM_API` is set, so brew resolves formulae and casks from
    /// locally cloned taps instead of the JSON API.
    func isInstallFromAPIDisabled() async -> Bool
}
