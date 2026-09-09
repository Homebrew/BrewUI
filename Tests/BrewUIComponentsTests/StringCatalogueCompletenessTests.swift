//
//  StringCatalogueCompletenessTests.swift
//  BrewUIComponentsTests
//

import Foundation
import Testing

/// Every catalogue in the package must carry a translated `pt-BR` entry for every source string.
/// A missing translation is invisible at runtime — the key is returned, so the view renders English
/// inside an otherwise Portuguese screen. This is the only thing that makes it a build failure.
///
/// Reads the catalogue sources from the repository rather than a bundle: `.xcstrings` is compiled
/// into `.lproj` directories, so the authored JSON never reaches the test bundle.
struct StringCatalogueCompletenessTests {
    private static let requiredLanguage = "pt-BR"

    private static var packageRoot: URL {
        // .../Tests/BrewUIComponentsTests/ThisFile.swift → package root
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Flattened as siblings rather than nested inside `Catalogue`/`Localization`: swiftlint's
    /// nesting rule caps types at one level deep, and this file already spends that level on
    /// `Catalogue` itself.
    private struct Catalogue: Decodable {
        let sourceLanguage: String
        let strings: [String: CatalogueEntry]
    }

    private struct CatalogueEntry: Decodable {
        let localizations: [String: CatalogueLocalization]?
    }

    private struct CatalogueLocalization: Decodable {
        let stringUnit: CatalogueStringUnit?
        let variations: CatalogueVariations?

        /// A plural entry has no top-level `stringUnit`; every one of its cases must be translated.
        var isTranslated: Bool {
            if let stringUnit {
                return stringUnit.state == "translated"
            }
            guard let cases = variations?.plural, !cases.isEmpty else {
                return false
            }
            return cases.values.allSatisfy { $0.stringUnit.state == "translated" }
        }
    }

    private struct CatalogueStringUnit: Decodable {
        let state: String
    }

    private struct CatalogueVariations: Decodable {
        let plural: [String: CataloguePluralCase]?
    }

    private struct CataloguePluralCase: Decodable {
        let stringUnit: CatalogueStringUnit
    }

    /// The app target's catalogue sits outside `Sources/`, so it is named rather than walked to.
    /// Widening the walk to the repository root would also sweep `Tests/` and any future fixture
    /// catalogue — a bigger blast radius than one known path deserves.
    private static let appTargetCatalogue = "Homebrew/Localizable.xcstrings"

    private static func catalogueURLs() throws -> [URL] {
        let sources = packageRoot.appending(path: "Sources")
        let enumerator = FileManager.default.enumerator(
            at: sources,
            includingPropertiesForKeys: nil,
        )
        var found = enumerator?
            .compactMap { $0 as? URL }
            .filter { $0.lastPathComponent == "Localizable.xcstrings" } ?? []

        // Named, not discovered — so a moved or deleted app catalogue fails here instead of
        // quietly dropping out of the checked set.
        let appCatalogue = packageRoot.appending(path: appTargetCatalogue)
        guard FileManager.default.fileExists(atPath: appCatalogue.path) else {
            throw CatalogueNotFound(path: appTargetCatalogue)
        }
        found.append(appCatalogue)

        return found.sorted { $0.path < $1.path }
    }

    private struct CatalogueNotFound: Error, CustomStringConvertible {
        let path: String
        var description: String {
            "Expected a String Catalog at \(path). If it moved, update appTargetCatalogue."
        }
    }

    @Test func `every catalogue string has a translated pt-BR entry`() throws {
        var untranslated: [String] = []

        for url in try Self.catalogueURLs() {
            let catalogue = try JSONDecoder().decode(Catalogue.self, from: Data(contentsOf: url))
            let module = url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent

            for (key, entry) in catalogue.strings {
                let localization = entry.localizations?[Self.requiredLanguage]
                if localization?.isTranslated != true {
                    untranslated.append("\(module): \(key)")
                }
            }
        }

        #expect(untranslated.sorted() == [])
    }

    /// A catalogue that declares a different source language would silently change what the keys mean.
    @Test func `every catalogue declares English as its source language`() throws {
        let languages = try Self.catalogueURLs().map { url in
            try JSONDecoder().decode(Catalogue.self, from: Data(contentsOf: url)).sourceLanguage
        }
        #expect(Set(languages).subtracting(["en"]) == [])
    }
}
