//
//  BrewLegacyStorageMigration.swift
//  BrewAppStorage
//

import Foundation

/// One-time move off `~/Library/Application Support/Brew`.
public enum BrewLegacyStorageMigration {
    /// Rescues the named subdirectories, then deletes the legacy directory and everything left in
    /// it. Nothing is deleted until every rescue succeeds, so a failure retries on the next launch.
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

    /// File-at-a-time rather than moving the folder: the destination may already hold newer files,
    /// which win.
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
