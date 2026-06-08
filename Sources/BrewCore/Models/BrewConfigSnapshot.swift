//
//  BrewConfigSnapshot.swift
//  BrewCore
//

import Foundation

/// Presentation-free snapshot of `brew config` plus the effective `HOMEBREW_*` environment.
///
/// ``entries`` preserves the raw, ordered `Key: Value` pairs reported by `brew config` verbatim —
/// grouping and section labels are a presentation concern decided in the feature layer, not here.
/// ``environment`` is the effective `HOMEBREW_*` process environment, surfaced separately because it
/// is read from the host process rather than `brew`'s own self-report.
public struct BrewConfigSnapshot: Equatable, Sendable {
    public var entries: [BrewConfigEntry]
    public var environment: [BrewConfigEntry]

    public init(entries: [BrewConfigEntry], environment: [BrewConfigEntry] = []) {
        self.entries = entries
        self.environment = environment
    }
}

/// A single ordered `Key: Value` pair from `brew config` or the `HOMEBREW_*` environment.
public struct BrewConfigEntry: Equatable, Sendable {
    public let key: String
    public let value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}
