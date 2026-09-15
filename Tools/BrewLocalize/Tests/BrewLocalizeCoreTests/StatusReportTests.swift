@testable import BrewLocalizeCore
import Testing

@Suite("StatusReport")
struct StatusReportTests {
    @Test
    func `markdown renders one row per language with completion percentage`() throws {
        let status = try LocalizationStatus(catalogs: [(Fixtures.app, Fixtures.catalog(Fixtures.mixed))])
        #expect(StatusReport.markdown(status).contains("| en-GB | 1 | 1 | 3 | 20% |"))
    }

    @Test
    func `markdown says so when nothing is translated yet`() throws {
        let status = try LocalizationStatus(catalogs: [(Fixtures.app, Fixtures.catalog(#"{ "sourceLanguage" : "en", "strings" : {} }"#))])
        #expect(StatusReport.markdown(status).contains("_No translations yet._"))
    }

    @Test
    func `text and markdown both carry the missing-from-app warning`() throws {
        let status = try LocalizationStatus(catalogs: [(Fixtures.package, Fixtures.catalog(Fixtures.mixed))])
        let text = StatusReport.text(status)
        let markdown = StatusReport.markdown(status)
        #expect(text.contains("en-GB has translations in a package") && markdown.contains("> ⚠️ en-GB"))
    }
}
