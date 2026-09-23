//
//  HomebrewEnvironmentReading.swift
//  BrewCore
//

import Foundation

/// The environment Homebrew resolves from its configuration files, independent of the app's environment.
public protocol HomebrewEnvironmentReading: Sendable {
    /// True when brew resolves packages from local tap clones rather than the JSON API.
    func isInstallFromAPIDisabled() async -> Bool
}
