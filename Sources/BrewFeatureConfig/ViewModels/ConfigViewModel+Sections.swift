//
//  ConfigViewModel+Sections.swift
//  BrewFeatureConfig
//

import BrewCore
import Foundation

/// Read-only presentation surface of the Configuration tab — the four-card layout, the Copy report
/// string, and error-mapping helpers. Lives in its own extension so the editing surface
/// (`ConfigViewModel`) stays small.
extension ConfigViewModel {
    /// Grouped read-only cards in display order. Takes the snapshot so callers (typically
    /// `AsyncContentView`) can pass placeholder content for the redacted loading state. The
    /// `HOMEBREW_*` Environment surface is handled by the editor card and intentionally absent here.
    func sections(for snapshot: BrewConfigSnapshot) -> [ConfigSectionItem] {
        var result: [ConfigSectionItem] = []
        appendIfNonEmpty(&result, id: "homebrew", title: "Homebrew", group: .homebrew, in: snapshot.entries)
        appendIfNonEmpty(&result, id: "system", title: "System", group: .system, in: snapshot.entries)
        appendIfNonEmpty(&result, id: "build", title: "Build settings", group: .build, in: snapshot.entries)
        return result
    }

    /// Convenience for callers (mainly tests) that derive sections from the cached snapshot.
    var sections: [ConfigSectionItem] {
        guard let snapshot = state.value else {
            return []
        }
        return sections(for: snapshot)
    }

    var canCopyReport: Bool {
        state.value != nil
    }

    /// Pasteable diagnostic block — the thing a user drops into a Homebrew issue report. Always includes
    /// the effective `HOMEBREW_*` environment from the loaded snapshot, not the in-progress draft —
    /// pre-save edits aren't effective yet, so the report should describe what `brew` actually sees.
    var copyReport: String {
        var parts = sections.map { sectionReport(for: $0) }
        if let snapshot = state.value {
            let envBody = snapshot.environment.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            let envBlock = envBody.isEmpty ? "(none)" : envBody
            parts.append("Environment (HOMEBREW_*)\n\(envBlock)")
        }
        return parts.joined(separator: "\n\n")
    }

    private func sectionReport(for section: ConfigSectionItem) -> String {
        let body = section.rows
            .map { "\($0.label): \($0.value)" }
            .joined(separator: "\n")
        return body.isEmpty ? "\(section.title)\n(none)" : "\(section.title)\n\(body)"
    }

    /// `brew` could not be located — the view shows a dedicated empty state rather than the error chrome.
    var isBrewNotFound: Bool {
        guard case let .failed(error) = state else {
            return false
        }
        return error is BrewLookupError
    }

    var errorMessage: String {
        guard case let .failed(error) = state else {
            return ""
        }
        return userMessage(for: error)
    }

    // MARK: - Grouping

    enum ConfigGroup {
        case homebrew
        case system
        case build
    }

    private static let homebrewKeys: Set<String> = [
        "HOMEBREW_VERSION", "ORIGIN", "HEAD", "Last commit", "Branch",
        "Core tap JSON", "Core cask tap JSON", "HOMEBREW_PREFIX", "Homebrew Ruby",
    ]

    private static let buildKeys: Set<String> = [
        "HOMEBREW_CASK_OPTS", "HOMEBREW_DOWNLOAD_CONCURRENCY",
        "HOMEBREW_MAKE_JOBS", "HOMEBREW_FORBID_PACKAGES_FROM_PATHS",
    ]

    private func appendIfNonEmpty(
        _ result: inout [ConfigSectionItem],
        id: String,
        title: String,
        group: ConfigGroup,
        in entries: [BrewConfigEntry],
    ) {
        let rows = entries
            .filter { Self.group(for: $0.key) == group }
            .map { ConfigDisplayRow(id: $0.key, label: $0.key, value: $0.value) }
        guard !rows.isEmpty else {
            return
        }
        result.append(ConfigSectionItem(id: id, title: title, rows: rows))
    }

    /// Unknown keys fall through to `System` so tolerant parsing never drops a diagnostic line.
    private static func group(for key: String) -> ConfigGroup {
        if homebrewKeys.contains(key) {
            return .homebrew
        }
        if buildKeys.contains(key) {
            return .build
        }
        return .system
    }
}
