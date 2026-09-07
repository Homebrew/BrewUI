//
//  BrewLegacyStorageMigrationTests.swift
//  BrewAppStorageTests
//

@testable import BrewAppStorage
import Foundation
import Testing

/// A pair of throwaway directories standing in for the legacy and namespaced Application Support
/// folders, so no test ever reads or deletes anything in the real `~/Library`.
private struct MigrationFixture {
    let legacyURL: URL
    let destinationURL: URL

    init() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrewLegacyStorageMigrationTests-\(UUID().uuidString)", isDirectory: true)
        legacyURL = root.appendingPathComponent("Brew", isDirectory: true)
        destinationURL = root.appendingPathComponent("sh.brew.app", isDirectory: true)
    }

    func write(_ contents: String, to fileName: String, inLegacySubdirectory subdirectory: String) throws {
        try write(contents, to: fileName, under: legacyURL.appendingPathComponent(subdirectory, isDirectory: true))
    }

    func write(_ contents: String, to fileName: String, inDestinationSubdirectory subdirectory: String) throws {
        try write(
            contents,
            to: fileName,
            under: destinationURL.appendingPathComponent(subdirectory, isDirectory: true),
        )
    }

    func write(_ contents: String, toLegacyFileNamed fileName: String) throws {
        try write(contents, to: fileName, under: legacyURL)
    }

    func destinationContents(of subdirectory: String, fileName: String) -> String? {
        let url = destinationURL
            .appendingPathComponent(subdirectory, isDirectory: true)
            .appendingPathComponent(fileName)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func destinationFileNames(of subdirectory: String) -> [String] {
        let url = destinationURL.appendingPathComponent(subdirectory, isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return names.sorted()
    }

    var legacyDirectoryExists: Bool {
        FileManager.default.fileExists(atPath: legacyURL.path)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: legacyURL.deletingLastPathComponent())
    }

    private func write(_ contents: String, to fileName: String, under directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: directory.appendingPathComponent(fileName), options: .atomic)
    }
}

private func migrate(_ fixture: MigrationFixture, preserving names: [String] = ["CrashReports"]) -> Bool {
    BrewLegacyStorageMigration.run(
        preserving: names,
        from: fixture.legacyURL,
        into: fixture.destinationURL,
    )
}

struct BrewLegacyStorageMigrationTests {
    @Test func `a preserved subdirectory's files move to the new location`() throws {
        let fixture = MigrationFixture()
        defer { fixture.cleanup() }
        try fixture.write("boom", to: "crash-1000.log", inLegacySubdirectory: "CrashReports")

        _ = migrate(fixture)

        #expect(fixture.destinationContents(of: "CrashReports", fileName: "crash-1000.log") == "boom")
    }

    @Test func `the legacy directory is removed once the rescue succeeds`() throws {
        let fixture = MigrationFixture()
        defer { fixture.cleanup() }
        try fixture.write("boom", to: "crash-1000.log", inLegacySubdirectory: "CrashReports")

        let completed = migrate(fixture)

        #expect(completed && !fixture.legacyDirectoryExists)
    }

    @Test func `unpreserved leftovers are discarded with the legacy directory`() throws {
        let fixture = MigrationFixture()
        defer { fixture.cleanup() }
        try fixture.write("{}", toLegacyFileNamed: "formula-cache.json")

        _ = migrate(fixture)

        #expect(!fixture.legacyDirectoryExists)
    }

    @Test func `a run with no legacy directory reports completion and creates nothing`() {
        let fixture = MigrationFixture()
        defer { fixture.cleanup() }

        let completed = migrate(fixture)

        #expect(completed && !FileManager.default.fileExists(atPath: fixture.destinationURL.path))
    }

    @Test func `a second run is a no-op`() throws {
        let fixture = MigrationFixture()
        defer { fixture.cleanup() }
        try fixture.write("boom", to: "crash-1000.log", inLegacySubdirectory: "CrashReports")
        _ = migrate(fixture)

        let completed = migrate(fixture)

        #expect(completed && fixture.destinationFileNames(of: "CrashReports") == ["crash-1000.log"])
    }

    @Test func `a file already at the destination is kept over the legacy copy`() throws {
        let fixture = MigrationFixture()
        defer { fixture.cleanup() }
        try fixture.write("old", to: "crash-1000.log", inLegacySubdirectory: "CrashReports")
        try fixture.write("new", to: "crash-1000.log", inDestinationSubdirectory: "CrashReports")

        _ = migrate(fixture)

        #expect(fixture.destinationContents(of: "CrashReports", fileName: "crash-1000.log") == "new")
    }

    @Test func `legacy files merge alongside files already at the destination`() throws {
        let fixture = MigrationFixture()
        defer { fixture.cleanup() }
        try fixture.write("old", to: "crash-1000.log", inLegacySubdirectory: "CrashReports")
        try fixture.write("new", to: "crash-2000.log", inDestinationSubdirectory: "CrashReports")

        _ = migrate(fixture)

        #expect(fixture.destinationFileNames(of: "CrashReports") == ["crash-1000.log", "crash-2000.log"])
    }

    @Test func `a legacy directory without the preserved subdirectory is still removed`() throws {
        let fixture = MigrationFixture()
        defer { fixture.cleanup() }
        try fixture.write("{}", toLegacyFileNamed: "cask-cache.json")

        let completed = migrate(fixture)

        #expect(completed && !fixture.legacyDirectoryExists)
    }

    @Test func `nothing is preserved when no subdirectory names are given`() throws {
        let fixture = MigrationFixture()
        defer { fixture.cleanup() }
        try fixture.write("boom", to: "crash-1000.log", inLegacySubdirectory: "CrashReports")

        _ = migrate(fixture, preserving: [])

        #expect(!fixture.legacyDirectoryExists && fixture.destinationFileNames(of: "CrashReports").isEmpty)
    }
}
