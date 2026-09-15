import Foundation

public enum TranslationState: Sendable {
    case translated
    case needsReview
    case untranslated

    /// Worst unit wins so a partially reviewed plural still reads as needing work. An empty value
    /// counts as untranslated whatever its state: it would compile to a blank string, not a fallback.
    init(units: [StringCatalog.StringUnit]) {
        if units.isEmpty || units.contains(where: { $0.state == "new" || ($0.value ?? "").isEmpty }) {
            self = .untranslated
        } else if units.contains(where: { $0.state == "needs_review" }) {
            self = .needsReview
        } else {
            self = .translated
        }
    }
}

/// Per-language totals across every catalog, plus stale keys awaiting cleanup.
public struct LocalizationStatus: Equatable, Sendable {
    public struct LanguageCounts: Equatable, Sendable {
        public var translated = 0
        public var needsReview = 0
        public var untranslated = 0

        public var total: Int {
            translated + needsReview + untranslated
        }
    }

    public var translatableKeys = 0
    public var staleKeys = 0
    public var counts: [String: LanguageCounts] = [:]
    /// Languages present in a package catalog but absent from the app catalog, which is what
    /// macOS reads to offer the language in the per-app picker.
    public var languagesMissingFromApp: [String] = []

    public var languages: [String] {
        counts.keys.sorted()
    }

    public init() {}

    public init(catalogs: [(location: CatalogLocation, catalog: StringCatalog)]) {
        let allLanguages = catalogs.reduce(into: Set<String>()) { $0.formUnion($1.catalog.languages) }
        for language in allLanguages {
            counts[language] = LanguageCounts()
        }

        for (_, catalog) in catalogs {
            for entry in catalog.strings.values where entry.isTranslatable {
                if entry.isStale {
                    staleKeys += 1
                    continue
                }
                translatableKeys += 1
                for language in allLanguages {
                    let state = TranslationState(units: entry.localizations?[language]?.units ?? [])
                    switch state {
                    case .translated: counts[language]?.translated += 1
                    case .needsReview: counts[language]?.needsReview += 1
                    case .untranslated: counts[language]?.untranslated += 1
                    }
                }
            }
        }

        let appLanguages = catalogs.first { $0.location.isApp }?.catalog.languages ?? []
        languagesMissingFromApp = allLanguages.subtracting(appLanguages).sorted()
    }
}
