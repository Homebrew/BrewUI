//
//  HomebrewPkgVersion.swift
//  BrewCore
//

import Foundation

/// Renders Homebrew's `PkgVersion` — a formula's version with its revision appended as `_<revision>`
/// once the revision is non-zero, exactly as the keg is named in the Cellar.
///
/// A revision bump repackages the same upstream release, so `versions.stable` does not move; only
/// `revision` does. Reading `versions.stable` alone therefore reports an upgrade target identical to
/// the installed keg ("9.0.1 → 9.0.1") whenever the outdated package is a revision bump.
public enum HomebrewPkgVersion {
    /// Trimmed `version_revision`, or nil when there is no usable version string.
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
