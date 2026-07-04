//
//  BrewConfigSnapshot+Placeholdable.swift
//  BrewCore
//

import Foundation

extension BrewConfigSnapshot: Placeholdable {
    public static var placeholder: BrewConfigSnapshot {
        BrewConfigSnapshot(
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
        )
    }
}
