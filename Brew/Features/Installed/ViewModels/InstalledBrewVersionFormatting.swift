//
//  InstalledBrewVersionFormatting.swift
//  Brew
//

import Foundation

/// Display-only version rules for installed list rows (used from `InstalledViewModel`, not repositories).
enum InstalledBrewVersionFormatting {
    /// Applies the same prefix rules as listed installed versions (`v` only when absent).
    static func displayVersionLabel(trimmedRaw: String) -> String {
        if trimmedRaw.hasPrefix("v") || trimmedRaw.hasPrefix("V") {
            return trimmedRaw
        }
        return "v\(trimmedRaw)"
    }

    /// Optional raw tap/stable string → display label; nil when missing or whitespace-only after trim.
    static func upgradeDisplayLabel(from raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return nil
        }
        return displayVersionLabel(trimmedRaw: trimmed)
    }
}
