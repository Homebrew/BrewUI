//
//  EnvKeyDescriptor.swift
//  BrewFeatureConfig
//

import Foundation

/// Describes a `HOMEBREW_*` variable that the Configuration editor knows how to render — the label,
/// help copy and the right control kind for its value. Drives the typed editor surface; keys outside
/// the catalogue (custom rows) fall through to a plain string control.
struct EnvKeyDescriptor: Equatable, Identifiable {
    enum Kind: Equatable {
        case toggle
        case integer(minimum: Int, maximum: Int)
        case string
        case secret
    }

    let key: String
    let label: String
    let summary: String
    let kind: Kind

    var id: String {
        key
    }
}

/// Curated allowlist of `HOMEBREW_*` keys we expose with typed controls + help copy, and the read-only
/// install-time set we surface but never let the user edit.
enum EnvKeyCatalogue {
    static let editable: [EnvKeyDescriptor] = [
        EnvKeyDescriptor(
            key: "HOMEBREW_NO_ANALYTICS",
            label: "Disable analytics",
            summary: "Stops Homebrew from sending anonymous usage data.",
            kind: .toggle,
        ),
        EnvKeyDescriptor(
            key: "HOMEBREW_NO_AUTO_UPDATE",
            label: "Disable auto-update",
            summary: "Skips the automatic `brew update` before commands.",
            kind: .toggle,
        ),
        EnvKeyDescriptor(
            key: "HOMEBREW_NO_EMOJI",
            label: "Disable emoji",
            summary: "Renders `brew` output without celebratory emoji.",
            kind: .toggle,
        ),
        EnvKeyDescriptor(
            key: "HOMEBREW_NO_INSTALL_CLEANUP",
            label: "Disable install cleanup",
            summary: "Keeps old versions in the Cellar after upgrades.",
            kind: .toggle,
        ),
        EnvKeyDescriptor(
            key: "HOMEBREW_NO_INSTALL_UPGRADE",
            label: "Disable install-time upgrades",
            summary: "Stops `brew install` from upgrading already-installed dependencies. Can leave new formulae linked against older libraries — only enable if you know why you need it.",
            kind: .toggle,
        ),
        EnvKeyDescriptor(
            key: "HOMEBREW_DOWNLOAD_CONCURRENCY",
            label: "Download concurrency",
            summary: "Parallel downloads during install. Use a number, or leave empty for the default.",
            kind: .integer(minimum: 1, maximum: 64),
        ),
        EnvKeyDescriptor(
            key: "HOMEBREW_MAKE_JOBS",
            label: "Make jobs",
            summary: "Parallel jobs passed to `make` during source builds.",
            kind: .integer(minimum: 1, maximum: 64),
        ),
        EnvKeyDescriptor(
            key: "HOMEBREW_CASK_OPTS",
            label: "Cask options",
            summary: "Default flags appended to every `brew install --cask` invocation.",
            kind: .string,
        ),
        EnvKeyDescriptor(
            key: "HOMEBREW_FORBID_PACKAGES_FROM_PATHS",
            label: "Forbid path-installed packages",
            summary: "Refuse to install packages from outside Homebrew's prefix.",
            kind: .toggle,
        ),
        EnvKeyDescriptor(
            key: "HOMEBREW_GITHUB_API_TOKEN",
            label: "GitHub API token",
            summary: "Personal access token used for GitHub API calls (raises rate limits).",
            kind: .secret,
        ),
    ]

    /// `HOMEBREW_*` keys that `brew` only honours at install time — `brew.env` can't change them. We
    /// still surface them so the user sees a complete picture, but the editor marks them read-only.
    static let installTimeOnly: Set<String> = [
        "HOMEBREW_PREFIX",
        "HOMEBREW_REPOSITORY",
        "HOMEBREW_CELLAR",
        "HOMEBREW_LIBRARY",
    ]

    static func descriptor(forKey key: String) -> EnvKeyDescriptor? {
        editable.first { $0.key == key }
    }

    static func isInstallTimeOnly(_ key: String) -> Bool {
        installTimeOnly.contains(key)
    }

    /// Custom rows can set any `HOMEBREW_*` key that isn't already in the curated allowlist or the
    /// install-time set. Some of those keys (domain/path overrides, developer mode) have meaningful
    /// security or stability implications, so the editor gates them behind a second confirmation
    /// step. This classifier decides whether a given custom key needs that gate and what reason to
    /// surface in the confirmation banner.
    static func classifyCustomKey(_ key: String) -> CustomKeyClassification {
        if let reason = explicitDangerousCustomKeys[key] {
            return .dangerous(reason: reason)
        }
        if key.hasSuffix("_DOMAIN") {
            return .dangerous(reason: "Redirects a Homebrew download to the URL you set. Only paste a host you trust — a wrong or malicious value can route every download somewhere else.")
        }
        if key.hasSuffix("_PATH") {
            return .dangerous(reason: "Points brew at an alternate binary at the path you set. Every brew invocation will execute it — only set this if the path is one you control.")
        }
        return .safe
    }

    private static let explicitDangerousCustomKeys: [String: String] = [
        "HOMEBREW_BOTTLE_DOMAIN": "Redirects bottle downloads to the URL you set. Only paste a host you trust.",
        "HOMEBREW_ARTIFACT_DOMAIN": "Redirects artifact downloads to the URL you set. Only paste a host you trust.",
        "HOMEBREW_API_DOMAIN": "Redirects the Homebrew formulae JSON API to the URL you set. Only paste a host you trust.",
        "HOMEBREW_DEVELOPER": "Turns on Homebrew developer mode globally — exposes experimental commands and stricter warnings.",
        "HOMEBREW_SUDO_THROUGH_SUDO_USER": "Changes how brew elevates privileges. Set only if you know why you need it.",
    ]
}

/// Whether a custom-row key is something we should add to the draft on a single tap, or something we
/// should surface a confirmation step for first.
enum CustomKeyClassification: Equatable {
    case safe
    case dangerous(reason: String)
}

/// Outcome of an `addCustomRow` attempt. The view branches on this to clear the form, hold the
/// confirmation banner, or render a rejection message.
enum AddCustomRowOutcome: Equatable {
    case added
    case needsConfirmation
    case rejected
}

/// A dangerous custom row staged for confirmation. The view renders ``reason`` in the warning
/// banner above the Confirm / Cancel buttons.
struct PendingCustomRow: Equatable {
    let key: String
    let value: String
    let reason: String
}
