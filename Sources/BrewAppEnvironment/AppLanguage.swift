//
//  AppLanguage.swift
//  BrewAppEnvironment
//

import Foundation

/// The language choices exposed by BrewUI's Configuration page.
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public var id: String { rawValue }
}

/// Persists the user's language choice and applies it to the next app launch.
@MainActor
public final class AppLanguageStore {
    public static let preferenceKey = "BrewUI.appLanguage"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var language: AppLanguage {
        get {
            guard let rawValue = defaults.string(forKey: Self.preferenceKey),
                  let language = AppLanguage(rawValue: rawValue)
            else {
                return .system
            }
            return language
        }
        set {
            defaults.set(newValue.rawValue, forKey: Self.preferenceKey)
        }
    }

    /// Sets the per-app Apple language override before SwiftUI creates the first view.
    /// Removing the key restores the system language choice.
    public func applyLaunchOverride() {
        switch language {
        case .system:
            defaults.removeObject(forKey: "AppleLanguages")
        case let language:
            defaults.set([language.rawValue], forKey: "AppleLanguages")
        }
    }
}
