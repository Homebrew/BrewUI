//
//  ConfigPagePayload.swift
//  BrewFeatureConfig
//

import BrewCore
import Foundation

/// Bundles the two pieces of data the Configuration page renders together — the cached `brew config`
/// snapshot and the cached `brew.env` file — so `AsyncContentView` can drive both the read-only cards
/// and the editor card from a single `LoadState`.
struct ConfigPagePayload: Equatable, Sendable {
    let snapshot: BrewConfigSnapshot
    let envFile: BrewEnvFile
}

extension ConfigPagePayload: Placeholdable {
    /// Realistic stub content for the redacted loading state: enough rows in each card so the
    /// `.redacted` skeleton sizes the same as the eventual real content.
    static var placeholder: ConfigPagePayload {
        ConfigPagePayload(
            snapshot: BrewConfigSnapshot(
                entries: [
                    BrewConfigEntry(key: "HOMEBREW_VERSION", value: "0.0.0"),
                    BrewConfigEntry(key: "HOMEBREW_PREFIX", value: "/placeholder/prefix"),
                    BrewConfigEntry(key: "Homebrew Ruby", value: "0.0.0 => /placeholder/path/to/ruby"),
                    BrewConfigEntry(key: "CPU", value: "Placeholder CPU"),
                    BrewConfigEntry(key: "Clang", value: "0.0.0"),
                    BrewConfigEntry(key: "Git", value: "0.0.0 => /placeholder/path/to/git"),
                    BrewConfigEntry(key: "macOS", value: "00.0-placeholder"),
                    BrewConfigEntry(key: "HOMEBREW_MAKE_JOBS", value: "0"),
                    BrewConfigEntry(key: "HOMEBREW_DOWNLOAD_CONCURRENCY", value: "0"),
                ],
                environment: [],
            ),
            envFile: BrewEnvFile(),
        )
    }
}
