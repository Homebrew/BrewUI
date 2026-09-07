//
//  BrewAppStorageLocations.swift
//  BrewAppStorage
//

import Foundation

/// The per-user directories the app owns on disk. Unsandboxed, so there is no container to
/// namespace writes and `~/Library` is shared ground. A store belongs in Caches only if losing
/// it costs nothing but a refetch.
public enum BrewAppStorageLocations {
    /// Not read from `Bundle.main`: tests and the crash-signal path must resolve the app's own
    /// directories. Pinned to `PRODUCT_BUNDLE_IDENTIFIER` by a test.
    public static let bundleIdentifier = "sh.brew.app"

    public static let legacyDirectoryName = "Brew"

    public static var cachesDirectoryURL: URL {
        namespaced(.cachesDirectory)
    }

    public static var applicationSupportDirectoryURL: URL {
        namespaced(.applicationSupportDirectory)
    }

    /// Read only to migrate off it; nothing should write here.
    public static var legacyApplicationSupportDirectoryURL: URL {
        base(.applicationSupportDirectory).appendingPathComponent(legacyDirectoryName, isDirectory: true)
    }

    private static func namespaced(_ directory: FileManager.SearchPathDirectory) -> URL {
        base(directory).appendingPathComponent(bundleIdentifier, isDirectory: true)
    }

    /// Falls back to the temporary directory so a store always has somewhere to write.
    private static func base(_ directory: FileManager.SearchPathDirectory) -> URL {
        let fileManager = FileManager.default
        return fileManager.urls(for: directory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
    }
}
