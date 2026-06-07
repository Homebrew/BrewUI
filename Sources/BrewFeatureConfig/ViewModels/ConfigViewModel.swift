//
//  ConfigViewModel.swift
//  BrewFeatureConfig
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

@Observable
@MainActor
final class ConfigViewModel {
    @ObservationIgnored private let repository: any ConfigRepository

    /// Drives the loading / loaded / failed chrome. Carries the underlying `Error` so this view model
    /// can map it to user-facing copy (`CONVENTIONS.md` — Loadable UI state).
    private(set) var state: LoadState<BrewConfigSnapshot, any Error> = .loading

    init(repository: any ConfigRepository) {
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            state = try await .loaded(repository.loadConfig())
        } catch {
            state = .failed(error)
        }
    }

    func refresh() async {
        await load()
    }

    // MARK: - Presentation

    /// Grouped cards in display order. `Homebrew` / `System` / `Build settings` only appear when populated;
    /// the `HOMEBREW_*` environment card always appears so it can report an empty environment.
    var sections: [ConfigSectionItem] {
        guard let snapshot = state.value else {
            return []
        }
        var result: [ConfigSectionItem] = []
        appendIfNonEmpty(&result, id: "homebrew", title: "Homebrew", group: .homebrew, in: snapshot.entries)
        appendIfNonEmpty(&result, id: "system", title: "System", group: .system, in: snapshot.entries)
        appendIfNonEmpty(&result, id: "build", title: "Build settings", group: .build, in: snapshot.entries)
        result.append(
            ConfigSectionItem(
                id: "environment",
                title: "Environment (HOMEBREW_*)",
                rows: snapshot.environment.map { ConfigDisplayRow(id: $0.key, label: $0.key, value: $0.value) },
                emptyMessage: String(
                    localized: "No HOMEBREW_* environment variables are set.",
                    comment: "Configuration tab, empty environment card",
                ),
            ),
        )
        return result
    }

    var canCopyReport: Bool {
        state.value != nil
    }

    /// Pasteable diagnostic block — the thing a user drops into a Homebrew issue report.
    var copyReport: String {
        sections.map { section in
            let body = section.rows
                .map { "\($0.label): \($0.value)" }
                .joined(separator: "\n")
            return body.isEmpty ? "\(section.title)\n(none)" : "\(section.title)\n\(body)"
        }
        .joined(separator: "\n\n")
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
        if case let BrewCommandError.failed(_, stderr) = error {
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return String(
            localized: "Couldn't read the Homebrew configuration.",
            comment: "Configuration tab, generic load failure",
        )
    }

    // MARK: - Grouping

    private enum ConfigGroup {
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
