@testable import BrewLocalizeCore
import Testing

@Suite("LocalizationStatus")
struct LocalizationStatusTests {
    private func mixedStatus() throws -> LocalizationStatus {
        try LocalizationStatus(catalogs: [(Fixtures.app, Fixtures.catalog(Fixtures.mixed))])
    }

    @Test
    func `counts each translation state once`() throws {
        let counts = try #require(mixedStatus().counts["en-GB"])
        // Translated; Review; New + Missing + partially translated plural.
        #expect(counts == .init(translated: 1, needsReview: 1, untranslated: 3))
    }

    @Test
    func `stale keys are reported separately and not counted per language`() throws {
        let status = try mixedStatus()
        #expect(status.staleKeys == 1 && status.translatableKeys == 5)
    }

    @Test
    func `do-not-translate keys are ignored`() throws {
        let status = try mixedStatus()
        #expect(status.counts["en-GB"]?.total == status.translatableKeys)
    }

    @Test
    func `source language is never a translation target`() throws {
        let catalog = try Fixtures.catalog("""
        {
          "sourceLanguage" : "en",
          "strings" : {
            "Key" : { "comment" : "c", "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Key" } } } }
          }
        }
        """)
        let status = LocalizationStatus(catalogs: [(Fixtures.app, catalog)])
        #expect(status.languages.isEmpty)
    }

    @Test
    func `a language only in a package catalog is flagged as missing from the app`() throws {
        let packageCatalog = try Fixtures.catalog(Fixtures.mixed)
        let appCatalog = try Fixtures.catalog(#"{ "sourceLanguage" : "en", "strings" : {} }"#)
        let status = LocalizationStatus(catalogs: [(Fixtures.package, packageCatalog), (Fixtures.app, appCatalog)])
        #expect(status.languagesMissingFromApp == ["en-GB"])
    }

    @Test
    func `a language present in both catalogs is not flagged`() throws {
        let catalog = try Fixtures.catalog(Fixtures.mixed)
        let status = LocalizationStatus(catalogs: [(Fixtures.package, catalog), (Fixtures.app, catalog)])
        #expect(status.languagesMissingFromApp.isEmpty)
    }

    @Test
    func `keys missing in one language count as untranslated for every language`() throws {
        let catalog = try Fixtures.catalog("""
        {
          "sourceLanguage" : "en",
          "strings" : {
            "A" : { "comment" : "c", "localizations" : { "fr" : { "stringUnit" : { "state" : "translated", "value" : "A" } } } },
            "B" : { "comment" : "c", "localizations" : { "de" : { "stringUnit" : { "state" : "translated", "value" : "B" } } } }
          }
        }
        """)
        let status = LocalizationStatus(catalogs: [(Fixtures.app, catalog)])
        #expect(status.counts["fr"] == .init(translated: 1, needsReview: 0, untranslated: 1))
    }
}
