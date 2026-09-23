//
//  UserDefaultsInstalledPreferences.swift
//  BrewRepositories
//

import BrewRepositoryInterfaces
import Foundation
import Observation

@Observable
@MainActor
public final class UserDefaultsInstalledPreferences: InstalledPreferences {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let defaultsKeyPrefix: String

    public var hideDependencies: Bool {
        didSet {
            defaults.set(hideDependencies, forKey: Keys.hideDependencies(prefix: defaultsKeyPrefix))
        }
    }

    /// Prefixed under `-uiTesting` so a UI test cannot write into the real app's preferences.
    public init(defaults: UserDefaults = .standard, defaultsKeyPrefix: String = "installed") {
        self.defaults = defaults
        self.defaultsKeyPrefix = defaultsKeyPrefix
        hideDependencies = defaults.bool(forKey: Keys.hideDependencies(prefix: defaultsKeyPrefix))
    }

    private enum Keys {
        static func hideDependencies(prefix: String) -> String {
            "\(prefix).hideDependencies"
        }
    }
}
