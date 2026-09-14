import BrewAppEnvironment
import Foundation
import Testing

struct AppLanguageStoreTests {
    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "BrewUI.AppLanguageTests.\(UUID().uuidString)"))
    }

    @Test func `language defaults to system`() throws {
        let defaults = try makeDefaults()

        #expect(AppLanguageStore(defaults: defaults).language == .system)
    }

    @Test func `language round trips through user defaults`() throws {
        let defaults = try makeDefaults()
        let store = AppLanguageStore(defaults: defaults)

        store.language = .simplifiedChinese

        #expect(AppLanguageStore(defaults: defaults).language == .simplifiedChinese)
    }

    @Test func `launch override follows the selected language`() throws {
        let suite = "BrewUI.AppLanguageTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let store = AppLanguageStore(defaults: defaults)

        store.language = .english
        store.applyLaunchOverride()
        #expect(defaults.array(forKey: "AppleLanguages") as? [String] == ["en"])

        store.language = .simplifiedChinese
        store.applyLaunchOverride()
        #expect(defaults.array(forKey: "AppleLanguages") as? [String] == ["zh-Hans"])

        store.language = .system
        store.applyLaunchOverride()
        #expect(defaults.persistentDomain(forName: suite)?["AppleLanguages"] == nil)
    }
}
