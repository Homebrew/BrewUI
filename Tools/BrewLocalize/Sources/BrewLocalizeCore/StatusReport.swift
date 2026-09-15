import Foundation

/// Renders a `LocalizationStatus` as plain text for terminals or Markdown for a CI job summary.
public enum StatusReport {
    public static func text(_ status: LocalizationStatus) -> String {
        var lines = ["\(status.translatableKeys) translatable strings, \(status.staleKeys) stale"]
        if status.languages.isEmpty {
            lines.append("No translations yet.")
        }
        for language in status.languages {
            let counts = status.counts[language] ?? .init()
            lines.append(
                "\(language): \(counts.translated) translated, \(counts.needsReview) need review, "
                    + "\(counts.untranslated) untranslated (\(percent(counts))%)",
            )
        }
        lines.append(contentsOf: appWarnings(status))
        return lines.joined(separator: "\n")
    }

    public static func markdown(_ status: LocalizationStatus) -> String {
        var lines = [
            "## Localization status",
            "",
            "\(status.translatableKeys) translatable strings · \(status.staleKeys) stale",
            "",
        ]
        if status.languages.isEmpty {
            lines.append("_No translations yet._")
        } else {
            lines.append("| Language | Translated | Needs review | Untranslated | Complete |")
            lines.append("|---|---:|---:|---:|---:|")
            for language in status.languages {
                let counts = status.counts[language] ?? .init()
                lines.append(
                    "| \(language) | \(counts.translated) | \(counts.needsReview) | \(counts.untranslated) "
                        + "| \(percent(counts))% |",
                )
            }
        }
        for warning in appWarnings(status) {
            lines.append("")
            lines.append("> ⚠️ \(warning)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func percent(_ counts: LocalizationStatus.LanguageCounts) -> Int {
        guard counts.total > 0 else {
            return 0
        }
        return counts.translated * 100 / counts.total
    }

    private static func appWarnings(_ status: LocalizationStatus) -> [String] {
        status.languagesMissingFromApp.map {
            "\($0) has translations in a package but none in \(CatalogLocation.appCatalogPath); "
                + "macOS will not offer it in the per-app language picker until the app catalog has one."
        }
    }
}
