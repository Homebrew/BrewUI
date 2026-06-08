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
}

/// A single label/value row within a ``ConfigSectionItem``.
struct ConfigDisplayRow: Identifiable {
    let id: String
    let label: String
    let value: String
}
