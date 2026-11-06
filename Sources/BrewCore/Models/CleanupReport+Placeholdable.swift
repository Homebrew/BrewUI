//
//  CleanupReport+Placeholdable.swift
//  BrewCore
//

import Foundation

extension CleanupReport: Placeholdable {
    /// Sized like a typical preview so the redacted skeleton matches the loaded layout.
    public static var placeholder: CleanupReport {
        CleanupReport(
            pruneAll: false,
            unneededFormulae: ["placeholder-formula"],
            removals: [
                CleanupRemoval(path: "/placeholder/Library/Caches/Homebrew/placeholder.bottle.tar.gz", kind: .file, size: "12.7MB"),
                CleanupRemoval(path: "/placeholder/Cellar/placeholder/1.0.0", kind: .file, size: "42 files, 3.1MB"),
                CleanupRemoval(path: "/placeholder/Library/Logs/Homebrew/placeholder", kind: .file, size: "64B"),
            ],
            reclaimableSpace: "15.8MB",
        )
    }
}
