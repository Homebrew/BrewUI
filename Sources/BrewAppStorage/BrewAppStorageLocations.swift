//
//  BrewAppStorageLocations.swift
//  BrewAppStorage
//

import Foundation

/// The per-user directories the app owns on disk.
///
/// The app is unsandboxed, so it writes into the shared `~/Library` rather than a container:
/// every directory is namespaced by bundle identifier so nothing collides with the `brew`
/// CLI's own `Homebrew` folders, or with anything else called `Brew`.
///
/// Which of the two roots a store belongs in is decided by whether its contents can be
/// rebuilt: ``cachesDirectoryURL`` is purgeable by the system and excluded from backups,
/// ``applicationSupportDirectoryURL`` is neither.
public enum BrewAppStorageLocations {
    /// Matches `PRODUCT_BUNDLE_IDENTIFIER`. Spelled out rather than read from `Bundle.main` so
    /// unit tests and the crash-signal path resolve the same directories the app does.
    public static let bundleIdentifier = "sh.brew.app"

    /// The single directory every store shared before the move to bundle-identifier namespacing.
    public static let legacyDirectoryName = "Brew"

    /// Regenerable content — anything a refetch or a recompute can replace.
    public static var cachesDirectoryURL: URL {
        namespaced(.cachesDirectory)
    }

    /// App-owned data that a purge would destroy for good.
    public static var applicationSupportDirectoryURL: URL {
        namespaced(.applicationSupportDirectory)
    }

    /// `~/Library/Application Support/Brew` — read only to migrate off it.
    public static var legacyApplicationSupportDirectoryURL: URL {
        base(.applicationSupportDirectory).appendingPathComponent(legacyDirectoryName, isDirectory: true)
    }

    private static func namespaced(_ directory: FileManager.SearchPathDirectory) -> URL {
        base(directory).appendingPathComponent(bundleIdentifier, isDirectory: true)
    }

    /// Falls back to the temporary directory so a store still has somewhere to write when the
    /// search path cannot be resolved.
    private static func base(_ directory: FileManager.SearchPathDirectory) -> URL {
        let fileManager = FileManager.default
        return fileManager.urls(for: directory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
    }
}
