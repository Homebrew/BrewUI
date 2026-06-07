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
}
