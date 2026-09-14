import BrewUIComponents
import Foundation
import Testing

@MainActor
struct LocalizationPreferencesTests {
    private func withDefaults(_ body: (UserDefaults, String) throws -> Void) throws {
        let domain = "BrewUI.LanguageTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        try body(defaults, domain)
    }

    private func preferences(_ defaults: UserDefaults, _: String) -> LanguagePreferences {
        LanguagePreferences(defaults: defaults, localizations: ["Base", "zh-Hans", "en", "en"])
    }

    @Test func `inherited language still means follow system`() throws {
        try withDefaults { defaults, domain in
            defaults.register(defaults: ["AppleLanguages": ["zh-Hans"]])
            #expect(preferences(defaults, domain).selectedLanguage == nil)
        }
    }

    @Test func `selection survives A new preferences instance`() throws {
        try withDefaults { defaults, domain in
            preferences(defaults, domain).select("zh-Hans")
            #expect(preferences(defaults, domain).selectedLanguage == "zh-Hans")
        }
    }

    @Test func `system choice removes only the application override`() throws {
        try withDefaults { defaults, domain in
            defaults.set("keep", forKey: "unrelated")
            let model = preferences(defaults, domain)
            model.select("zh-Hans")
            model.select(nil)
            let saved = defaults.persistentDomain(forName: domain) ?? [:]
            #expect(saved["appLanguage"] == nil && saved["unrelated"] as? String == "keep")
        }
    }

    @Test func `unsupported selection does not change preferences`() throws {
        try withDefaults { defaults, domain in
            let model = preferences(defaults, domain)
            model.select("../../untrusted")
            #expect(model.selectedLanguage == nil && defaults.persistentDomain(forName: domain)?["appLanguage"] == nil)
        }
    }

    @Test func `selection immediately changes the active locale`() throws {
        try withDefaults { defaults, domain in
            let model = preferences(defaults, domain)
            model.select("zh-Hans")
            #expect(model.localization.locale.identifier == "zh-Hans")
            model.select(nil)
            #expect(model.selectedLanguage == nil)
        }
    }

    @Test func `selection does not write apple languages`() throws {
        try withDefaults { defaults, domain in
            defaults.set(["ja"], forKey: "AppleLanguages")
            preferences(defaults, domain).select("zh-Hans")
            #expect(defaults.stringArray(forKey: "AppleLanguages") == ["ja"])
        }
    }

    @Test func `resources determine available languages`() throws {
        try withDefaults { defaults, _ in
            let model = LanguagePreferences(defaults: defaults, localizations: ["Base", "ja", "zh-Hans", "ja"])
            #expect(Set(model.availableLanguages) == Set(["en", "ja", "zh-Hans"]))
        }
    }
}

@MainActor
struct LocalizationResourceTests {
    private func withBundle(_ body: (Bundle) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        defer { try? FileManager.default.removeItem(at: root) }
        for (language, value) in [("en", "Installed"), ("zh-Hans", "已安装"), ("zh-Hant", "已安裝")] {
            let folder = root.appendingPathComponent(language + ".lproj")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try "\"Installed\" = \"\(value)\";".write(
                to: folder.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8,
            )
        }
        let bundle = try #require(Bundle(url: root))
        try body(bundle)
    }

    @Test func `existing preferences resolve new language in the same process`() throws {
        try withBundle { bundle in
            let model = LanguagePreferences(defaults: nil, bundle: bundle, preferredLanguages: ["en"])
            let initial = model.localization.string("Installed")
            model.select("zh-Hans")
            let translated = model.localization.string("Installed")
            model.select("en")
            #expect([initial, translated, model.localization.string("Installed")] == ["Installed", "已安装", "Installed"])
        }
    }

    @Test func `three languages share one preference and message instance`() throws {
        try withBundle { bundle in
            let model = LanguagePreferences(defaults: nil, bundle: bundle, preferredLanguages: ["en"])
            let message = AppMessage.localized("Installed")
            var labels: [String] = []
            for language in ["zh-Hans", "zh-Hant", "en"] {
                model.select(language)
                labels.append(message.string(localization: model.localization))
            }
            #expect(labels == ["已安装", "已安裝", "Installed"])
        }
    }

    @Test func `traditional chinese system preferences resolve the script resource`() {
        for language in ["zh-TW", "zh-HK", "zh-Hant"] {
            let model = LanguagePreferences(
                defaults: nil, localizations: ["en", "zh-Hans", "zh-Hant"], preferredLanguages: [language],
            )
            #expect(model.localization.locale.identifier == "zh-Hant")
        }
    }

    @Test func `unknown keys fall back to the source text`() throws {
        try withBundle { bundle in
            #expect(AppLocalization(language: "zh-Hans", bundle: bundle).string("Untranslated") == "Untranslated")
        }
    }

    @Test func `raw messages are never looked up as translation keys`() throws {
        try withBundle { bundle in
            let localization = AppLocalization(language: "zh-Hans", bundle: bundle)
            #expect(AppMessage.raw("Installed").string(localization: localization) == "Installed")
        }
    }

    @Test func `an already stored message uses the current language`() throws {
        try withBundle { bundle in
            let message = AppMessage.localized("Installed")
            #expect(message.string(localization: AppLocalization(language: "zh-Hans", bundle: bundle)) == "已安装")
        }
    }

    @Test func `right to left language has native layout direction`() {
        #expect(AppLocalization(language: "ar").layoutDirection == .rightToLeft)
    }

    @Test func `unsupported system language uses english`() {
        let model = LanguagePreferences(defaults: nil, localizations: ["en", "zh-Hans"], preferredLanguages: ["fr"])
        #expect(model.localization.locale.identifier == "en")
    }
}
