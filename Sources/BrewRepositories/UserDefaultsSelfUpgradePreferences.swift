//
//  UserDefaultsSelfUpgradePreferences.swift
//  BrewRepositories
//

import BrewRepositoryInterfaces
import Foundation
import Observation

@Observable
@MainActor
public final class UserDefaultsSelfUpgradePreferences: SelfUpgradePreferences {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let defaultsKeyPrefix: String

    public var dismissedVersion: String? {
        didSet {
            let key = Keys.dismissedVersion(prefix: defaultsKeyPrefix)
            if let dismissedVersion {
                defaults.set(dismissedVersion, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    /// The composition root prefixes the keys under `-uiTesting`, so a UI test cannot write into the real
    /// app's preferences. The default prefix reproduces the original key name.
    public init(defaults: UserDefaults = .standard, defaultsKeyPrefix: String = "selfUpgrade") {
        self.defaults = defaults
        self.defaultsKeyPrefix = defaultsKeyPrefix
        dismissedVersion = defaults.string(forKey: Keys.dismissedVersion(prefix: defaultsKeyPrefix))
    }

    private enum Keys {
        static func dismissedVersion(prefix: String) -> String {
            "\(prefix).dismissedVersion"
        }
    }
}
