@testable import BrewLocalizeCore
import Testing

@Suite("CatalogVerification")
struct CatalogVerificationTests {
    @Test
    func `a commented catalog in a UI target has no problems`() throws {
        let catalog = try Fixtures.catalog(Fixtures.mixed)
        #expect(CatalogVerification.problems(in: catalog, at: Fixtures.package).isEmpty)
    }

    @Test
    func `a catalog outside the UI layer is rejected`() throws {
        let catalog = try Fixtures.catalog(#"{ "sourceLanguage" : "en", "strings" : {} }"#)
        let location = CatalogLocation(path: "Sources/BrewCore/Resources/Localizable.xcstrings")
        #expect(CatalogVerification.problems(in: catalog, at: location).count == 1)
    }

    @Test
    func `a key without a comment is reported by name`() throws {
        let catalog = try Fixtures.catalog("""
        { "sourceLanguage" : "en", "strings" : { "Run Again" : {}, "Copy" : { "comment" : " " } } }
        """)
        let messages = CatalogVerification.problems(in: catalog, at: Fixtures.package).map(\.message)
        #expect(messages.count == 2 && messages.allSatisfy { $0.contains("has no comment") })
    }

    @Test
    func `stale and do-not-translate keys need no comment`() throws {
        let catalog = try Fixtures.catalog("""
        {
          "sourceLanguage" : "en",
          "strings" : {
            "Old" : { "extractionState" : "stale" },
            "brew" : { "shouldTranslate" : false }
          }
        }
        """)
        #expect(CatalogVerification.problems(in: catalog, at: Fixtures.package).isEmpty)
    }
}
