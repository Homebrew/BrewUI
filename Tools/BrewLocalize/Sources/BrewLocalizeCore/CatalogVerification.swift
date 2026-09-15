import Foundation

/// Checks that keep catalogs useful to translators and confined to UI targets.
public enum CatalogVerification {
    public struct Problem: Equatable, Sendable, CustomStringConvertible {
        public let path: String
        public let message: String

        public var description: String {
            "\(path): error: \(message)"
        }
    }

    public static func problems(in catalog: StringCatalog, at location: CatalogLocation) -> [Problem] {
        var problems: [Problem] = []
        if !location.isInAllowedLayer {
            problems.append(Problem(
                path: location.path,
                message: "Catalogs belong only to UI targets (Sources/BrewUIComponents, Sources/BrewFeature*, Homebrew). "
                    + "Throw a typed error enum from this layer and word it in BrewUIComponents/Copy.",
            ))
        }
        for (key, entry) in catalog.strings.sorted(by: { $0.key < $1.key })
            where entry.isTranslatable && !entry.isStale
        {
            let comment = entry.comment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if comment.isEmpty {
                problems.append(Problem(
                    path: location.path,
                    message: "\"\(key)\" has no comment. Pass `comment:` at the call site so translators get context.",
                ))
            }
            for (language, localization) in entry.localizations ?? [:] where language != catalog.sourceLanguage {
                if localization.units.contains(where: { ($0.value ?? "").isEmpty }) {
                    problems.append(Problem(
                        path: location.path,
                        message: "\"\(key)\" has an empty \(language) translation, which would show as blank text. "
                            + "Remove the entry to fall back to English.",
                    ))
                }
            }
        }
        return problems.sorted { ($0.path, $0.message) < ($1.path, $1.message) }
    }
}
