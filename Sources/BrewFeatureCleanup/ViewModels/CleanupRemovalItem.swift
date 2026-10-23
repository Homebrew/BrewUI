//
//  CleanupRemovalItem.swift
//  BrewFeatureCleanup
//

import BrewCore
import Foundation

/// One row in the Cleanup list: the path Homebrew would remove and what it said about it.
struct CleanupRemovalItem: Identifiable, Equatable {
    let id: String
    let path: String
    /// Homebrew's size text, or why a sizeless path is going.
    let detail: String?

    init(removal: CleanupRemoval) {
        id = removal.id
        path = removal.path
        detail = switch removal.kind {
        case .file:
            removal.size
        case .brokenLink:
            String(localized: "Broken link", bundle: #bundle, comment: "Cleanup row: the path is a symlink whose target is gone")
        case .emptyDirectory:
            String(localized: "Empty folder", bundle: #bundle, comment: "Cleanup row: the path is an empty directory")
        }
    }
}
