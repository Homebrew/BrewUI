//
//  InstalledBrewVersionFormatting.swift
//  BrewCore
//

import Foundation

/// Display-only version rules shared by installed and discover surfaces (used from view models, not repositories).
public enum InstalledBrewVersionFormatting {
    /// Applies the same prefix rules as listed installed versions (`v` only when absent).
    public static func displayVersionLabel(trimmedRaw: String) -> String {
        if trimmedRaw.hasPrefix("v") || trimmedRaw.hasPrefix("V") {
            return trimmedRaw
        }
        return "v\(trimmedRaw)"
    }

    /// Optional raw tap/stable string → display label; nil when missing or whitespace-only after trim.
    public static func upgradeDisplayLabel(from raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return nil
        }
        return displayVersionLabel(trimmedRaw: trimmed)
    }
}
