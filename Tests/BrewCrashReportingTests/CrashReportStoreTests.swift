//
//  CrashReportStoreTests.swift
//  BrewTests
//

@testable import BrewCrashReporting
import Foundation
import Testing

private func makeTemporaryStore() -> CrashReportStore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CrashReportStoreTests-\(UUID().uuidString)", isDirectory: true)
    return CrashReportStore(directoryURL: directory)
}

struct CrashReportStoreTests {
    @Test func `save then pending reports round-trips the text`() throws {
        let store = makeTemporaryStore()
        let saved = try store.save(text: "boom", date: Date(timeIntervalSince1970: 1000))

        let pending = store.pendingReports()

        #expect(pending == [saved])
    }

    @Test func `pending reports are ordered oldest first`() throws {
        let store = makeTemporaryStore()
        try store.save(text: "newer", date: Date(timeIntervalSince1970: 2000))
        try store.save(text: "older", date: Date(timeIntervalSince1970: 1000))

        let texts = store.pendingReports().map(\.text)

        #expect(texts == ["older", "newer"])
    }

    @Test func `capture time is recovered from the file name`() throws {
        let store = makeTemporaryStore()
        let date = Date(timeIntervalSince1970: 1234.567)
        try store.save(text: "boom", date: date)

        let captured = try #require(store.pendingReports().first).capturedAt

        // File names carry millisecond precision, so allow sub-millisecond drift.
        #expect(abs(captured.timeIntervalSince(date)) < 0.001)
    }

    @Test func `remove deletes a single report`() throws {
        let store = makeTemporaryStore()
        let first = try store.save(text: "first", date: Date(timeIntervalSince1970: 1000))
        try store.save(text: "second", date: Date(timeIntervalSince1970: 2000))

        store.remove(first)

        #expect(store.pendingReports().map(\.text) == ["second"])
    }

    @Test func `remove all clears every report`() throws {
        let store = makeTemporaryStore()
        try store.save(text: "a", date: Date(timeIntervalSince1970: 1000))
        try store.save(text: "b", date: Date(timeIntervalSince1970: 2000))

        store.removeAll()

        #expect(store.pendingReports().isEmpty)
    }

    @Test func `unrelated files in the directory are ignored`() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CrashReportStoreTests-\(UUID().uuidString)", isDirectory: true)
        let store = CrashReportStore(directoryURL: directory)
        try store.ensureDirectoryExists()
        try Data("noise".utf8).write(to: directory.appendingPathComponent("notes.txt"))
        let saved = try store.save(text: "boom", date: Date(timeIntervalSince1970: 1000))

        #expect(store.pendingReports() == [saved])
    }

    @Test func `pending reports is empty when the directory is absent`() {
        let store = makeTemporaryStore()

        #expect(store.pendingReports().isEmpty)
    }
}
