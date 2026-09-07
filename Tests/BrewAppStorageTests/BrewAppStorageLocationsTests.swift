//
//  BrewAppStorageLocationsTests.swift
//  BrewAppStorageTests
//

@testable import BrewAppStorage
import Foundation
import Testing

private func searchPathURL(_ directory: FileManager.SearchPathDirectory) throws -> URL {
    try #require(FileManager.default.urls(for: directory, in: .userDomainMask).first)
}

struct BrewAppStorageLocationsTests {
    @Test func `caches directory is namespaced by bundle identifier`() throws {
        let expected = try searchPathURL(.cachesDirectory)
            .appendingPathComponent("sh.brew.app", isDirectory: true)

        #expect(BrewAppStorageLocations.cachesDirectoryURL == expected)
    }

    @Test func `application support directory is namespaced by bundle identifier`() throws {
        let expected = try searchPathURL(.applicationSupportDirectory)
            .appendingPathComponent("sh.brew.app", isDirectory: true)

        #expect(BrewAppStorageLocations.applicationSupportDirectoryURL == expected)
    }

    @Test func `legacy directory is the unnamespaced application support folder`() throws {
        let expected = try searchPathURL(.applicationSupportDirectory)
            .appendingPathComponent("Brew", isDirectory: true)

        #expect(BrewAppStorageLocations.legacyApplicationSupportDirectoryURL == expected)
    }

    @Test func `caches and application support are different directories`() {
        #expect(BrewAppStorageLocations.cachesDirectoryURL != BrewAppStorageLocations.applicationSupportDirectoryURL)
    }

    @Test func `bundle identifier matches the product bundle identifier`() {
        #expect(BrewAppStorageLocations.bundleIdentifier == "sh.brew.app")
    }
}
