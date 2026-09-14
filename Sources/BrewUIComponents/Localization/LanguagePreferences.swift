import Foundation
import Observation

@Observable
@MainActor
public final class LanguagePreferences {
    public private(set) var selectedLanguage: String?
    public let activeSelection: String?
    public let availableLanguages: [String]
    public let activeLanguage: String
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private let bundle: Bundle
    @ObservationIgnored private let systemPreferredLanguages: [String]
    private static let preferenceKey = "appLanguage"
    private static let appleLanguagesKey = "AppleLanguages"
    private static let migrationKey = "languagePreferenceUsesNativeLaunch"

    public init(
        defaults: UserDefaults? = .standard,
        localizations: [String]? = nil,
        bundle: Bundle = .main,
        preferredLanguages: [String] = Locale.preferredLanguages,
        systemPreferredLanguages: [String]? = nil,
    ) {
        self.defaults = defaults
        self.bundle = bundle
        self.systemPreferredLanguages = systemPreferredLanguages ?? Self.defaultSystemPreferredLanguages()
        let languages = Set((localizations ?? bundle.localizations) + ["en"])
            .filter { $0 != "Base" && !$0.isEmpty && !$0.contains("/") && !$0.contains(".") }
            .sorted()
        availableLanguages = languages

        let saved = defaults?.string(forKey: Self.preferenceKey)
        let initialSelection = saved.flatMap { languages.contains($0) ? $0 : nil }
        selectedLanguage = initialSelection
        let launchLanguage = Self.resolveLanguage(from: languages, preferences: preferredLanguages)
        activeLanguage = launchLanguage
        let initialLanguage = initialSelection ?? Self.resolveLanguage(from: languages, preferences: self.systemPreferredLanguages)
        activeSelection = initialLanguage == launchLanguage ? initialSelection : launchLanguage
    }

    /// Call before creating the SwiftUI app. Migrate only the injected domain; do not persist an inherited system language as an app selection.
    public static func prepareForLaunch(
        defaults: UserDefaults, domain: String, localizations: [String], applyNativeOverride: ([String]?) -> Void = { _ in },
    ) -> [String]? {
        let languages = localizations.filter { $0 != "Base" }
        if !defaults.bool(forKey: migrationKey) {
            if defaults.persistentDomain(forName: domain)?[appleLanguagesKey] == nil,
               let old = defaults.string(forKey: preferenceKey), languages.contains(old)
            {
                defaults.set([old], forKey: appleLanguagesKey)
            }
            defaults.set(true, forKey: migrationKey)
        }
        let override = defaults.persistentDomain(forName: domain)?[appleLanguagesKey] as? [String]
        // Install the process-level test override before any language-matching query so the framework does not cache the system language first.
        applyNativeOverride(override)
        if let override {
            defaults.set(resolveLanguage(from: languages, preferences: override), forKey: preferenceKey)
        } else {
            defaults.removeObject(forKey: preferenceKey)
        }
        return override
    }

    public var pendingLaunchArguments: [String] {
        ["-AppleLanguages", "(\(resolvedPendingLanguage))"]
    }

    public var hasPendingChange: Bool {
        resolvedPendingLanguage != activeLanguage
    }

    public var localization: AppLocalization {
        AppLocalization(language: activeLanguage, bundle: bundle)
    }

    public func select(_ language: String?) {
        guard language == nil || availableLanguages.contains(language ?? "") else { return }
        selectedLanguage = language
        if let language {
            defaults?.set(language, forKey: Self.preferenceKey)
            defaults?.set([language], forKey: Self.appleLanguagesKey)
        } else {
            defaults?.removeObject(forKey: Self.preferenceKey)
            defaults?.removeObject(forKey: Self.appleLanguagesKey)
        }
    }

    public var resolvedPendingLanguage: String {
        guard let selectedLanguage else {
            return Self.resolveLanguage(from: availableLanguages, preferences: systemPreferredLanguages)
        }
        return selectedLanguage
    }

    private static func resolveLanguage(from availableLanguages: [String], preferences: [String]) -> String {
        Bundle.preferredLocalizations(from: availableLanguages, forPreferences: preferences).first ?? "en"
    }

    private static func defaultSystemPreferredLanguages() -> [String] {
        guard
            let globalDomain = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain),
            let languages = globalDomain[appleLanguagesKey] as? [String],
            !languages.isEmpty
        else {
            return ["en"]
        }
        return languages
    }
}
