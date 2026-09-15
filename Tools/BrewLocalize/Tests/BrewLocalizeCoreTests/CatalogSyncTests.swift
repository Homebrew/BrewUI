@testable import BrewLocalizeCore
import Foundation
import Testing

/// Merges handcrafted compiler output with the real `xcstringstool`, so these need an Xcode toolchain.
@Suite("CatalogSync")
struct CatalogSyncTests {
    private static let emptyCatalog = #"{ "sourceLanguage" : "en", "version" : "1.0", "strings" : {} }"#
    private static let location = CatalogLocation(path: "Sources/BrewFeatureDoctor/Resources/Localizable.xcstrings")
    private static let sourcePath = "Sources/BrewFeatureDoctor/Views/DoctorView.swift"

    private static func stringsdata(source: URL) -> String {
        """
        {
          "source": "\(source.path)",
          "tables": {
            "Localizable": [
              { "comment": "Heading", "key": "Doctor", "location": { "startingColumn": 1, "startingLine": 1 } },
              { "comment": "Button", "key": "%lld packages", "location": { "startingColumn": 1, "startingLine": 2 } }
            ]
          },
          "version": 1
        }
        """
    }

    private func makeRepo() throws -> (repo: TemporaryRepo, index: StringsDataIndex) {
        let repo = try TemporaryRepo.make(files: [
            Self.location.path: Self.emptyCatalog,
            Self.sourcePath: "",
        ])
        let stringsdataDirectory = repo.url.appendingPathComponent("stringsdata")
        try FileManager.default.createDirectory(at: stringsdataDirectory, withIntermediateDirectories: true)
        try Self.stringsdata(source: repo.url.appendingPathComponent(Self.sourcePath))
            .write(to: stringsdataDirectory.appendingPathComponent("DoctorView.stringsdata"), atomically: true, encoding: .utf8)
        return (repo, StringsDataIndex(directories: [stringsdataDirectory]))
    }

    @Test
    func `sync writes extracted keys and comments into the catalog`() throws {
        let (repo, index) = try makeRepo()
        defer { repo.remove() }
        let outcome = try CatalogSync.sync(Self.location, root: repo.url, index: index, check: false)
        let catalog = try StringCatalog(contentsOf: repo.url.appendingPathComponent(Self.location.path))
        #expect(!outcome.changed && Set(catalog.strings.keys) == ["Doctor", "%lld packages"]
            && catalog.strings["Doctor"]?.comment == "Heading")
    }

    @Test
    func `check reports drift without touching the catalog`() throws {
        let (repo, index) = try makeRepo()
        defer { repo.remove() }
        let outcome = try CatalogSync.sync(Self.location, root: repo.url, index: index, check: true)
        let unchanged = try String(contentsOf: repo.url.appendingPathComponent(Self.location.path), encoding: .utf8)
        #expect(outcome.changed && outcome.diff.contains("+    \"Doctor\"") && unchanged == Self.emptyCatalog)
    }

    @Test
    func `check passes once the catalog matches the sources`() throws {
        let (repo, index) = try makeRepo()
        defer { repo.remove() }
        _ = try CatalogSync.sync(Self.location, root: repo.url, index: index, check: false)
        let outcome = try CatalogSync.sync(Self.location, root: repo.url, index: index, check: true)
        #expect(!outcome.changed)
    }

    @Test
    func `a key that left the code is marked stale, not deleted, when translated`() throws {
        let (repo, index) = try makeRepo()
        defer { repo.remove() }
        let translated = """
        { "sourceLanguage" : "en", "version" : "1.0", "strings" : {
          "Gone" : { "comment" : "c", "localizations" : { "fr" : { "stringUnit" : { "state" : "translated", "value" : "Parti" } } } }
        } }
        """
        try translated.write(to: repo.url.appendingPathComponent(Self.location.path), atomically: true, encoding: .utf8)
        _ = try CatalogSync.sync(Self.location, root: repo.url, index: index, check: false)
        let catalog = try StringCatalog(contentsOf: repo.url.appendingPathComponent(Self.location.path))
        #expect(catalog.strings["Gone"]?.isStale == true)
    }

    @Test
    func `a target with no sources leaves the catalog as it is`() throws {
        let repo = try TemporaryRepo.make(files: [Self.location.path: Self.emptyCatalog])
        defer { repo.remove() }
        let outcome = try CatalogSync.sync(Self.location, root: repo.url, index: StringsDataIndex(), check: true)
        #expect(!outcome.changed)
    }

    @Test
    func `a source without string data fails loudly`() throws {
        let repo = try TemporaryRepo.make(files: [Self.location.path: Self.emptyCatalog, Self.sourcePath: ""])
        defer { repo.remove() }
        #expect(throws: StringsDataIndex.Failure.self) {
            try CatalogSync.sync(Self.location, root: repo.url, index: StringsDataIndex(), check: true)
        }
    }
}
