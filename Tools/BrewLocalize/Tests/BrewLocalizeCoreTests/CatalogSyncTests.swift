@testable import BrewLocalizeCore
import Foundation
import Testing

/// Runs the real `xcstringstool` against a throwaway target, so these need an Xcode toolchain.
@Suite("CatalogSync")
struct CatalogSyncTests {
    private static let emptyCatalog = #"{ "sourceLanguage" : "en", "version" : "1.0", "strings" : {} }"#
    private static let source = """
    import SwiftUI
    struct V: View {
        var body: some View {
            Text("Doctor", bundle: #bundle, comment: "Heading")
            Button(String(localized: "Run Again", bundle: #bundle, comment: "Button")) {}
            Text(verbatim: "v1.2")
        }
    }
    """
    private static let location = CatalogLocation(path: "Sources/BrewFeatureDoctor/Resources/Localizable.xcstrings")

    @Test
    func `sync writes extracted keys and comments into the catalog`() throws {
        let repo = try TemporaryRepo.make(files: [
            Self.location.path: Self.emptyCatalog,
            "Sources/BrewFeatureDoctor/Views/V.swift": Self.source,
        ])
        defer { repo.remove() }
        let outcome = try CatalogSync.sync(Self.location, root: repo.url, check: false)
        let catalog = try StringCatalog(contentsOf: repo.url.appendingPathComponent(Self.location.path))
        #expect(!outcome.changed && Set(catalog.strings.keys) == ["Doctor", "Run Again"]
            && catalog.strings["Run Again"]?.comment == "Button")
    }

    @Test
    func `check reports drift without touching the catalog`() throws {
        let repo = try TemporaryRepo.make(files: [
            Self.location.path: Self.emptyCatalog,
            "Sources/BrewFeatureDoctor/Views/V.swift": Self.source,
        ])
        defer { repo.remove() }
        let outcome = try CatalogSync.sync(Self.location, root: repo.url, check: true)
        let unchanged = try String(contentsOf: repo.url.appendingPathComponent(Self.location.path), encoding: .utf8)
        #expect(outcome.changed && outcome.diff.contains("+    \"Run Again\"") && unchanged == Self.emptyCatalog)
    }

    @Test
    func `check passes once the catalog matches the sources`() throws {
        let repo = try TemporaryRepo.make(files: [
            Self.location.path: Self.emptyCatalog,
            "Sources/BrewFeatureDoctor/Views/V.swift": Self.source,
        ])
        defer { repo.remove() }
        _ = try CatalogSync.sync(Self.location, root: repo.url, check: false)
        let outcome = try CatalogSync.sync(Self.location, root: repo.url, check: true)
        #expect(!outcome.changed)
    }

    @Test
    func `a target with no sources leaves the catalog as it is`() throws {
        let repo = try TemporaryRepo.make(files: [Self.location.path: Self.emptyCatalog])
        defer { repo.remove() }
        let outcome = try CatalogSync.sync(Self.location, root: repo.url, check: true)
        #expect(!outcome.changed)
    }
}
