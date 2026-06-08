//
//  CaskOpts.swift
//  BrewFeatureConfig
//

import Foundation

/// Advisory classification of a `HOMEBREW_CASK_OPTS` value. We surface it inline next to the field so
/// a user pasting a value can see whether their tokens are recognised, and whether any of them turn
/// off a default `brew install --cask` safety behaviour.
struct CaskOptsAdvisory: Equatable {
    /// Flag tokens (the `--name` portion before any `=`) that aren't in the recognised set. Surfaced
    /// as a "review this paste" chip — values are never auto-rejected, since the upstream allow-list
    /// can drift.
    var unrecognisedFlags: [String]
    /// `--no-quarantine` is present somewhere in the value. Disables macOS Gatekeeper quarantine on
    /// downloaded casks — worth calling out explicitly because the security implication is non-obvious.
    var hasNoQuarantine: Bool
    /// `--force` is present somewhere in the value. Overrides several install-time safety checks.
    var hasForce: Bool

    var isClean: Bool {
        unrecognisedFlags.isEmpty && !hasNoQuarantine && !hasForce
    }
}

/// Recognised `brew install --cask` flags plus a tokeniser that walks the user's pasted value and
/// classifies each flag token. Non-flag tokens (values for `--appdir`, etc.) are ignored — the
/// advisory only judges what's after a `--`.
enum CaskOpts {
    /// Flags `brew` documents under `--cask` install. Anything outside this set produces an
    /// "unrecognised" chip in the UI, but the user is still allowed to save — `brew` may grow flags
    /// faster than this list.
    static let recognisedFlags: Set<String> = [
        "--appdir",
        "--colorpickerdir",
        "--prefpanedir",
        "--qlplugindir",
        "--dictionarydir",
        "--fontdir",
        "--input-methoddir",
        "--internet-plugindir",
        "--keyboard-layoutdir",
        "--mdimporterdir",
        "--screen-saverdir",
        "--service-dir",
        "--audio-unit-plugindir",
        "--vst-plugindir",
        "--vst3-plugindir",
        "--language",
        "--require-sha",
        "--no-binaries",
        "--no-quarantine",
        "--force",
    ]

    static func advisory(for raw: String) -> CaskOptsAdvisory {
        var unrecognised: [String] = []
        var hasNoQuarantine = false
        var hasForce = false
        for rawToken in raw.split(whereSeparator: \.isWhitespace) {
            let token = String(rawToken)
            guard token.hasPrefix("--") else {
                // Bare value (`/Applications` after `--appdir`, etc.) — ignore.
                continue
            }
            // Treat `--flag=value` and `--flag value` as the same flag for classification.
            let flagName = token.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                .first
                .map(String.init) ?? token
            if recognisedFlags.contains(flagName) {
                if flagName == "--no-quarantine" {
                    hasNoQuarantine = true
                } else if flagName == "--force" {
                    hasForce = true
                }
            } else if !unrecognised.contains(flagName) {
                unrecognised.append(flagName)
            }
        }
        return CaskOptsAdvisory(
            unrecognisedFlags: unrecognised,
            hasNoQuarantine: hasNoQuarantine,
            hasForce: hasForce,
        )
    }
}
