import Foundation
import Observation

@Observable
@MainActor
public final class LanguagePreferences {
    public private(set) var selectedLanguage: String?
    public let availableLanguages: [String]
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private let bundle: Bundle
    @ObservationIgnored private let preferredLanguages: [String]
    private static let preferenceKey = "appLanguage"

    public init(
        defaults: UserDefaults? = .standard,
        localizations: [String]? = nil,
        bundle: Bundle = .main,
        preferredLanguages: [String] = Locale.preferredLanguages,
    ) {
        self.defaults = defaults
        self.bundle = bundle
        self.preferredLanguages = preferredLanguages
        availableLanguages = Set((localizations ?? bundle.localizations) + ["en"])
            .filter { $0 != "Base" && !$0.isEmpty && !$0.contains("/") && !$0.contains(".") }
            .sorted()
        let saved = defaults?.string(forKey: Self.preferenceKey)
        selectedLanguage = saved.flatMap { availableLanguages.contains($0) ? $0 : nil }
    }

    public var localization: AppLocalization {
        let language = selectedLanguage ?? Bundle.preferredLocalizations(
            from: availableLanguages,
            forPreferences: preferredLanguages,
        ).first ?? "en"
        return AppLocalization(language: language, bundle: bundle)
    }

    public func select(_ language: String?) {
        guard language == nil || availableLanguages.contains(language ?? "") else { return }
        selectedLanguage = language
        if let language {
            defaults?.set(language, forKey: Self.preferenceKey)
        } else {
            defaults?.removeObject(forKey: Self.preferenceKey)
        }
    }
}
