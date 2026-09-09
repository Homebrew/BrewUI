//
//  StringCatalogueCompletenessTests.swift
//  BrewUIComponentsTests
//

import Foundation
import Testing

/// A catalogue that has begun translating into a language must finish: every key it holds needs a
/// translated entry in every language that any of its keys declares.
///
/// This enforces consistency, not language policy. Which languages the project accepts, and whether
/// a new string must arrive with a translation, is the project's call — a module nobody has started
/// translating declares no second language and passes untouched. What the rule does catch is the
/// half-translated module, and that distinction matters because the failure is invisible at runtime:
/// a missing entry returns the key, so an otherwise Portuguese screen renders one English button and
/// nothing else notices.
///
/// Reads the catalogue sources from the repository rather than a bundle: `.xcstrings` is compiled
/// into `.lproj` directories, so the authored JSON never reaches the test bundle.
struct StringCatalogueCompletenessTests {
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

    /// Walking two directories up from the app catalogue reaches the checkout folder, whose name is
    /// whatever the person cloning chose. Every other catalogue sits at `<module>/Resources/`.
    private static let appTargetLabel = "Homebrew"

    /// Every catalogue that exists today. The `Sources/` walk still finds any others, so a new
    /// module's catalogue is checked the day it lands — but a walk that returns nothing, because a
    /// directory was renamed or the layout restructured, fails here instead of passing a suite that
    /// silently checked only the deliberately empty app catalogue.
    private static let requiredCatalogues = [
        "Sources/BrewFeatureDoctor/Resources/Localizable.xcstrings",
        "Sources/BrewUIComponents/Resources/Localizable.xcstrings",
        appTargetCatalogue,
    ]

    private static func catalogueURLs() throws -> [URL] {
        let sources = packageRoot.appending(path: "Sources")
        let enumerator = FileManager.default.enumerator(
            at: sources,
            includingPropertiesForKeys: nil,
        )
        let walked = (enumerator?.compactMap { $0 as? URL } ?? [])
            .filter { $0.lastPathComponent == "Localizable.xcstrings" }

        var found = Set(walked.map(\.standardizedFileURL))
        for relativePath in requiredCatalogues {
            let url = packageRoot.appending(path: relativePath).standardizedFileURL
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw CatalogueNotFound(path: relativePath)
            }
            found.insert(url)
        }

        return found.sorted { $0.path < $1.path }
    }

    private static func moduleLabel(for url: URL) -> String {
        guard url != packageRoot.appending(path: appTargetCatalogue).standardizedFileURL else {
            return appTargetLabel
        }
        return url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
    }

    private struct CatalogueNotFound: Error, CustomStringConvertible {
        let path: String
        var description: String {
            "Expected a String Catalog at \(path). If it moved, update requiredCatalogues."
        }
    }

    @Test func `a catalogue that translates a string into a language translates all of them`() throws {
        var untranslated: [String] = []

        for url in try Self.catalogueURLs() {
            let catalogue = try JSONDecoder().decode(Catalogue.self, from: Data(contentsOf: url))
            let module = Self.moduleLabel(for: url)
            let languages = Set(catalogue.strings.values.compactMap(\.localizations).flatMap(\.keys))

            for language in languages {
                for (key, entry) in catalogue.strings where entry.localizations?[language]?.isTranslated != true {
                    untranslated.append("\(module) [\(language)]: \(key)")
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
