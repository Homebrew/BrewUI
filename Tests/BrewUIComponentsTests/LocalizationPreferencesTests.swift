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

    private func preferences(
        _ defaults: UserDefaults,
        _: String,
        preferredLanguages: [String] = ["en"],
        systemPreferredLanguages: [String] = ["en"],
    ) -> LanguagePreferences {
        LanguagePreferences(
            defaults: defaults,
            localizations: ["Base", "zh-Hans", "en", "en"],
            preferredLanguages: preferredLanguages,
            systemPreferredLanguages: systemPreferredLanguages,
        )
    }

    @Test func `launch migrates legacy selection only within the injected domain`() throws {
        try withDefaults { defaults, domain in
            defaults.set("zh-Hans", forKey: "appLanguage")
            let languages = LanguagePreferences.prepareForLaunch(defaults: defaults, domain: domain, localizations: ["en", "zh-Hans"])
            #expect(languages == ["zh-Hans"] && defaults.stringArray(forKey: "AppleLanguages") == ["zh-Hans"])
        }
    }

    @Test func `launch respects an existing native app language over legacy selection`() throws {
        try withDefaults { defaults, domain in
            defaults.set("zh-Hans", forKey: "appLanguage")
            defaults.set(["en"], forKey: "AppleLanguages")
            _ = LanguagePreferences.prepareForLaunch(defaults: defaults, domain: domain, localizations: ["en", "zh-Hans"])
            #expect(defaults.string(forKey: "appLanguage") == "en")
        }
    }

    @Test func `removing native override after migration does not resurrect legacy language`() throws {
        try withDefaults { defaults, domain in
            defaults.set("zh-Hans", forKey: "appLanguage")
            _ = LanguagePreferences.prepareForLaunch(defaults: defaults, domain: domain, localizations: ["en", "zh-Hans"])
            defaults.removeObject(forKey: "AppleLanguages")
            let languages = LanguagePreferences.prepareForLaunch(defaults: defaults, domain: domain, localizations: ["en", "zh-Hans"])
            #expect(languages == nil && defaults.string(forKey: "appLanguage") == nil)
        }
    }

    @Test func `global inherited languages are not copied into app override`() throws {
        try withDefaults { defaults, domain in
            defaults.register(defaults: ["AppleLanguages": ["zh-Hans"]])
            let languages = LanguagePreferences.prepareForLaunch(defaults: defaults, domain: domain, localizations: ["en", "zh-Hans"])
            #expect(languages == nil && defaults.persistentDomain(forName: domain)?["AppleLanguages"] == nil)
        }
    }

    @Test func `inherited language still means follow system`() throws {
        try withDefaults { defaults, domain in
            defaults.register(defaults: ["AppleLanguages": ["zh-Hans"]])
            let model = preferences(defaults, domain)
            #expect(model.selectedLanguage == nil && model.activeSelection == nil && !model.hasPendingChange)
        }
    }

    @Test func `selection survives a new preferences instance as pending state`() throws {
        try withDefaults { defaults, domain in
            let first = preferences(defaults, domain)
            first.select("zh-Hans")
            let second = preferences(defaults, domain)
            #expect(
                second.selectedLanguage == "zh-Hans"
                    && second.activeSelection == "en"
                    && second.activeLanguage == "en"
                    && second.hasPendingChange,
            )
        }
    }

    @Test func `legacy app language remains the initial pending selection`() throws {
        try withDefaults { defaults, domain in
            defaults.set("zh-Hans", forKey: "appLanguage")
            let model = preferences(defaults, domain)
            #expect(
                model.selectedLanguage == "zh-Hans"
                    && model.activeSelection == "en"
                    && model.activeLanguage == "en"
                    && model.localization.locale.identifier == "en"
                    && model.hasPendingChange,
            )
        }
    }

    @Test func `undo restores the selection captured at startup`() throws {
        try withDefaults { defaults, domain in
            defaults.set("zh-Hans", forKey: "appLanguage")
            let model = preferences(defaults, domain, preferredLanguages: ["zh-Hans"])
            model.select("en")
            model.select(model.activeSelection)
            #expect(model.selectedLanguage == "zh-Hans" && !model.hasPendingChange)
        }
    }

    @Test func `undo during migration restores the actual launch language`() throws {
        try withDefaults { defaults, domain in
            defaults.set("zh-Hans", forKey: "appLanguage")
            let model = preferences(defaults, domain, preferredLanguages: ["en"])
            model.select(model.activeSelection)
            #expect(!model.hasPendingChange && model.selectedLanguage == "en")
        }
    }

    @Test func `system choice removes only the application override`() throws {
        try withDefaults { defaults, domain in
            defaults.set("keep", forKey: "unrelated")
            let model = preferences(defaults, domain)
            model.select("zh-Hans")
            model.select(nil)
            let saved = defaults.persistentDomain(forName: domain) ?? [:]
            #expect(
                saved["appLanguage"] == nil
                    && saved["AppleLanguages"] == nil
                    && saved["unrelated"] as? String == "keep",
            )
        }
    }

    @Test func `unsupported selection does not change preferences`() throws {
        try withDefaults { defaults, domain in
            let model = preferences(defaults, domain)
            model.select("../../untrusted")
            #expect(
                model.selectedLanguage == nil
                    && model.activeLanguage == "en"
                    && !model.hasPendingChange
                    && defaults.persistentDomain(forName: domain)?["appLanguage"] == nil
                    && defaults.persistentDomain(forName: domain)?["AppleLanguages"] == nil,
            )
        }
    }

    @Test func `selection waits for the next launch to change the active locale`() throws {
        try withDefaults { defaults, domain in
            let model = preferences(defaults, domain)
            let initialLocalization = model.localization
            model.select("zh-Hans")
            #expect(
                model.selectedLanguage == "zh-Hans"
                    && model.activeLanguage == "en"
                    && model.localization.locale.identifier == "en"
                    && initialLocalization.locale.identifier == "en"
                    && model.hasPendingChange,
            )
        }
    }

    @Test func `reverting to follow system clears a pending change`() throws {
        try withDefaults { defaults, domain in
            let model = preferences(defaults, domain)
            model.select("zh-Hans")
            model.select(nil)
            #expect(
                model.selectedLanguage == nil
                    && model.activeSelection == nil
                    && model.activeLanguage == "en"
                    && model.localization.locale.identifier == "en"
                    && !model.hasPendingChange,
            )
        }
    }

    @Test func `follow system resolves against the injected system preferences`() throws {
        try withDefaults { defaults, domain in
            let model = preferences(
                defaults,
                domain,
                preferredLanguages: ["en"],
                systemPreferredLanguages: ["zh-Hans"],
            )
            #expect(
                model.selectedLanguage == nil
                    && model.activeLanguage == "en"
                    && model.localization.locale.identifier == "en"
                    && model.hasPendingChange,
            )
            model.select("en")
            #expect(!model.hasPendingChange)
        }
    }

    @Test func `selection synchronizes the isolated apple languages override`() throws {
        try withDefaults { defaults, domain in
            let model = preferences(defaults, domain)
            model.select("zh-Hans")
            let saved = defaults.persistentDomain(forName: domain) ?? [:]
            #expect(
                saved["appLanguage"] as? String == "zh-Hans"
                    && saved["AppleLanguages"] as? [String] == ["zh-Hans"],
            )
        }
    }

    @Test func `new resource locale uses the same pending launch argument contract`() throws {
        try withDefaults { defaults, _ in
            let model = LanguagePreferences(defaults: defaults, localizations: ["en", "ja"], preferredLanguages: ["en"])
            model.select("ja")
            #expect(model.pendingLaunchArguments == ["-AppleLanguages", "(ja)"] && model.activeLanguage == "en")
        }
    }

    @Test func `follow system launch argument resolves a supported script language`() throws {
        try withDefaults { defaults, _ in
            let model = LanguagePreferences(
                defaults: defaults, localizations: ["en", "zh-Hant"], preferredLanguages: ["en"], systemPreferredLanguages: ["zh-HK"],
            )
            #expect(model.pendingLaunchArguments == ["-AppleLanguages", "(zh-Hant)"])
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

    private func preferences(bundle: Bundle, preferredLanguages: [String]) -> LanguagePreferences {
        LanguagePreferences(
            defaults: nil,
            localizations: ["en", "zh-Hans", "zh-Hant"],
            bundle: bundle,
            preferredLanguages: preferredLanguages,
            systemPreferredLanguages: ["en"],
        )
    }

    @Test func `selection keeps the current resources until a new instance starts`() throws {
        try withBundle { bundle in
            let model = preferences(bundle: bundle, preferredLanguages: ["en"])
            let message = AppMessage.localized("Installed")
            let initial = model.localization.string("Installed")
            model.select("zh-Hans")
            let deferred = message.string(localization: model.localization)
            let relaunched = preferences(bundle: bundle, preferredLanguages: ["zh-Hans"])
            let translated = message.string(localization: relaunched.localization)
            #expect([initial, deferred, translated] == ["Installed", "Installed", "已安装"])
        }
    }

    @Test func `three languages share one message across launch instances`() throws {
        try withBundle { bundle in
            let message = AppMessage.localized("Installed")
            let labels = ["zh-Hans", "zh-Hant", "en"].map { language in
                message.string(localization: preferences(bundle: bundle, preferredLanguages: [language]).localization)
            }
            #expect(labels == ["已安装", "已安裝", "Installed"])
        }
    }

    @Test func `traditional chinese system preferences resolve the script resource`() {
        for language in ["zh-TW", "zh-HK", "zh-Hant"] {
            let model = LanguagePreferences(
                defaults: nil,
                localizations: ["en", "zh-Hans", "zh-Hant"],
                preferredLanguages: [language],
                systemPreferredLanguages: ["en"],
            )
            #expect(model.activeLanguage == "zh-Hant")
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
        let model = LanguagePreferences(
            defaults: nil,
            localizations: ["en", "zh-Hans"],
            preferredLanguages: ["fr"],
            systemPreferredLanguages: ["fr"],
        )
        #expect(model.activeLanguage == "en" && model.localization.locale.identifier == "en")
    }
}
