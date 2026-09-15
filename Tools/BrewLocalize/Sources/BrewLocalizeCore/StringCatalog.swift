import Foundation

/// The subset of the `.xcstrings` schema the tool reads. Unknown keys are ignored so a newer Xcode
/// can add fields without breaking the parser.
public struct StringCatalog: Decodable, Sendable {
    public struct Entry: Decodable, Sendable {
        public var comment: String?
        public var extractionState: String?
        public var shouldTranslate: Bool?
        public var localizations: [String: Localization]?

        public var isStale: Bool {
            extractionState == "stale"
        }

        public var isTranslatable: Bool {
            shouldTranslate != false
        }
    }

    public struct Localization: Decodable, Sendable {
        public var stringUnit: StringUnit?
        public var variations: [String: [String: Localization]]?

        /// Every state reachable through plural/device variations, depth first.
        public var states: [String] {
            var result: [String] = []
            if let stringUnit {
                result.append(stringUnit.state)
            }
            for (_, cases) in variations ?? [:] {
                for (_, localization) in cases {
                    result.append(contentsOf: localization.states)
                }
            }
            return result
        }
    }

    public struct StringUnit: Decodable, Sendable {
        public var state: String
        public var value: String?
    }

    public var sourceLanguage: String
    public var version: String?
    public var strings: [String: Entry]

    public init(data: Data) throws {
        self = try JSONDecoder().decode(StringCatalog.self, from: data)
    }

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    /// Languages that have at least one localization, excluding the source language.
    public var languages: Set<String> {
        var result: Set<String> = []
        for entry in strings.values {
            for language in (entry.localizations ?? [:]).keys where language != sourceLanguage {
                result.insert(language)
            }
        }
        return result
    }
}
