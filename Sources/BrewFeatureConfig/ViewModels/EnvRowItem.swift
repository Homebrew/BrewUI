//
//  EnvRowItem.swift
//  BrewFeatureConfig
//

import Foundation

/// Where the displayed value for a row came from. Drives the provenance badge and the read-only hint
/// — it's a teaching moment for users moving from the app to the Terminal (`[[project-brewui-product-intent]]`).
enum EnvRowProvenance: Equatable {
    /// Value lives in `brew.env`. This is the editor's source of truth.
    case envFile
    /// Value is shadowed by a `HOMEBREW_*=…` in the shell environment, which always wins.
    case shell
    /// The key is in the catalogue but neither `brew.env` nor shell sets it — Homebrew's default applies.
    case defaultValue
    /// A user-added `HOMEBREW_*` row outside the curated allowlist (still backed by `brew.env`).
    case custom
}

/// Editor status for a row — `editable(kind)` drives the typed control; the read-only variants drive a
/// badge + hint explaining why the row can't be changed here.
enum EnvRowStatus: Equatable {
    case editable(EnvKeyDescriptor.Kind)
    case readOnlyShellOverridden(rcHint: String)
    case readOnlyInstallTime
}

/// What the editor view renders. The view doesn't do its own grouping or styling decisions — it reads
/// `status` to pick a control + chrome, and `provenance` to colour the badge.
struct EnvRowItem: Identifiable, Equatable {
    let id: String
    let key: String
    let value: String
    let provenance: EnvRowProvenance
    let status: EnvRowStatus
    let descriptor: EnvKeyDescriptor?
}
