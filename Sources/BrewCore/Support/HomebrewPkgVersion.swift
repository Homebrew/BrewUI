//
//  HomebrewPkgVersion.swift
//  BrewCore
//

import Foundation

/// Homebrew's `PkgVersion`: `version_revision` when the revision is non-zero, as the keg is named.
/// A revision bump leaves `versions.stable` untouched, so the bare version reads as no upgrade at all.
public enum HomebrewPkgVersion {
    public static func string(version: String?, revision: Int?) -> String? {
        guard let trimmed = version?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        guard let revision, revision > 0 else {
            return trimmed
        }
        return "\(trimmed)_\(revision)"
    }
}
