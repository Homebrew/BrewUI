//
//  ConfigSectionItem.swift
//  BrewFeatureConfig
//

import Foundation

/// A presentation-ready group of config rows (title + ordered rows), mapped from the domain snapshot so
/// the UI-free `BrewConfigSnapshot` never carries section labels (`CONVENTIONS.md` — presentation boundary).
struct ConfigSectionItem: Identifiable {
    let id: String
    let title: String
    let rows: [ConfigDisplayRow]
    /// When non-nil, the section renders this copy instead of being dropped when it has no rows
    /// (used for the `HOMEBREW_*` environment card, which stays visible to say "nothing is set").
    let emptyMessage: String?

    init(id: String, title: String, rows: [ConfigDisplayRow], emptyMessage: String? = nil) {
        self.id = id
        self.title = title
        self.rows = rows
        self.emptyMessage = emptyMessage
    }
}

/// A single label/value row within a ``ConfigSectionItem``.
struct ConfigDisplayRow: Identifiable {
    let id: String
    let label: String
    let value: String
}
