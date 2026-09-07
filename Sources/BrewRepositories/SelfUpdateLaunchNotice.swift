//
//  SelfUpdateLaunchNotice.swift
//  BrewRepositories
//

import BrewCore
import Foundation

/// The writer is a different process, so the helper opens the app's suite by name and is handed
/// ``storageKey`` rather than deriving it.
public struct SelfUpdateLaunchNotice {
    private let defaults: UserDefaults
    private let defaultsKeyPrefix: String

    public init(defaults: UserDefaults = .standard, defaultsKeyPrefix: String = "selfUpdate") {
        self.defaults = defaults
        self.defaultsKeyPrefix = defaultsKeyPrefix
    }

    public var storageKey: String {
        "\(defaultsKeyPrefix).lastUpdateOutcome"
    }

    /// Non-`nil` exactly once per completed attempt.
    public func consume() -> SelfUpdateOutcome? {
        guard let raw = defaults.string(forKey: storageKey) else {
            return nil
        }
        defaults.removeObject(forKey: storageKey)
        // An unrecognised value can only come from a helper newer than this app, so an attempt did happen.
        return SelfUpdateOutcome(rawValue: raw) ?? .succeeded
    }

    public func mark(_ outcome: SelfUpdateOutcome) {
        defaults.set(outcome.rawValue, forKey: storageKey)
    }
}
