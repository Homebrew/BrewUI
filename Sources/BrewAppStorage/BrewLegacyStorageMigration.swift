//
//  BrewLegacyStorageMigration.swift
//  BrewAppStorage
//

import Foundation

/// One-time move off `~/Library/Application Support/Brew`, the directory every store shared before
/// the app namespaced its storage by bundle identifier.
public enum BrewLegacyStorageMigration {
    /// Rescues the named subdirectories, then deletes the legacy directory and everything still in
    /// it — the caches that lived there are regenerable and have moved to `Caches` anyway.
    ///
    /// Nothing is deleted until every rescue has succeeded, so a failure leaves the legacy directory
    /// where it is and the next launch tries again. Returns whether the legacy directory is gone,
    /// which is the only thing a caller could act on; there is no user-facing failure here.
    @discardableResult
    public static func run(
        preserving subdirectoryNames: [String],
        from legacyDirectoryURL: URL = BrewAppStorageLocations.legacyApplicationSupportDirectoryURL,
        into destinationDirectoryURL: URL = BrewAppStorageLocations.applicationSupportDirectoryURL,
    ) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: legacyDirectoryURL.path) else {
            return true
        }

        do {
            for name in subdirectoryNames {
                try rescue(
                    subdirectoryNamed: name,
                    from: legacyDirectoryURL,
                    into: destinationDirectoryURL,
                    using: fileManager,
                )
            }
            try fileManager.removeItem(at: legacyDirectoryURL)
            return true
        } catch {
            return false
        }
    }

    /// Moves files one at a time rather than moving the folder, because the destination may already
    /// hold files written since the app moved: a name present on both sides keeps the newer copy.
    private static func rescue(
        subdirectoryNamed name: String,
        from legacyDirectoryURL: URL,
        into destinationDirectoryURL: URL,
        using fileManager: FileManager,
    ) throws {
        let source = legacyDirectoryURL.appendingPathComponent(name, isDirectory: true)
        guard let fileNames = try? fileManager.contentsOfDirectory(atPath: source.path) else {
            return
        }

        let destination = destinationDirectoryURL.appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        for fileName in fileNames {
            let target = destination.appendingPathComponent(fileName)
            guard !fileManager.fileExists(atPath: target.path) else {
                continue
            }
            try fileManager.moveItem(at: source.appendingPathComponent(fileName), to: target)
        }
    }
}
