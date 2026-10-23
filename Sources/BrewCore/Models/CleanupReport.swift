//
//  CleanupReport.swift
//  BrewCore
//

import Foundation

/// What `brew cleanup --dry-run` says a real `brew cleanup` would remove.
///
/// Actor-neutral domain value (no presentation). Homebrew owns every number in it: sizes and the total are
/// kept as the text Homebrew printed rather than recomputed, so the report never disagrees with the console.
public struct CleanupReport: Equatable, Sendable {
    /// Whether the preview ran with `--prune=all`, so a report is never shown for the other option.
    public var pruneAll: Bool
    /// Formulae `brew autoremove` would uninstall because nothing installed depends on them any more.
    public var unneededFormulae: [String]
    /// Stale downloads, old versions, logs and broken links, in the order Homebrew listed them.
    public var removals: [CleanupRemoval]
    /// Homebrew's own total, e.g. `67.5MB`; `nil` when it printed none, as it does when nothing would be freed.
    public var reclaimableSpace: String?
    public var rawOutput: String

    public init(
        pruneAll: Bool,
        unneededFormulae: [String],
        removals: [CleanupRemoval],
        reclaimableSpace: String?,
        rawOutput: String = "",
    ) {
        self.pruneAll = pruneAll
        self.unneededFormulae = unneededFormulae
        self.removals = removals
        self.reclaimableSpace = reclaimableSpace
        self.rawOutput = rawOutput
    }

    /// `true` when a real `brew cleanup` would change nothing.
    public var isEmpty: Bool {
        unneededFormulae.isEmpty && removals.isEmpty
    }
}

/// One path `brew cleanup` would remove.
public struct CleanupRemoval: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        /// A file or directory, usually with a size.
        case file
        /// A symlink whose target no longer exists.
        case brokenLink
        case emptyDirectory
    }

    public var path: String
    public var kind: Kind
    /// Homebrew's own size text, e.g. `12.7MB` or `815 files, 7.4MB`; `nil` when it printed none.
    public var size: String?

    public var id: String {
        path
    }

    public init(path: String, kind: Kind, size: String? = nil) {
        self.path = path
        self.kind = kind
        self.size = size
    }
}
