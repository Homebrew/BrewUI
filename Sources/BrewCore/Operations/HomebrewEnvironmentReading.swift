//
//  HomebrewEnvironmentReading.swift
//  BrewCore
//

import Foundation

/// The Homebrew environment as `brew` resolves it. Not `ProcessInfo`: the app is Finder-launched, so
/// a profile-exported `HOMEBREW_*` is invisible to it yet in effect for every brew invocation.
public protocol HomebrewEnvironmentReading: Sendable {
    /// True when brew resolves packages from local tap clones rather than the JSON API.
    func isInstallFromAPIDisabled() async -> Bool
}
