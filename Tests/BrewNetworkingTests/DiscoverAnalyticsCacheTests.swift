//
//  DiscoverAnalyticsCacheTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewNetworking
import Foundation
import Testing

struct DiscoverAnalyticsCacheTests {
    @Test @MainActor func `analytics data is nil before any write`() async {
        let fixture = TestFixture()
        defer { fixture.cleanup() }
        let cache = fixture.makeCache()

        #expect(await cache.formulaAnalyticsData(window: .days30) == nil)
        #expect(await cache.caskAnalyticsData(window: .days30) == nil)
        #expect(await cache.etag(for: .formula, window: .days30) == nil)
    }

    @Test @MainActor func `update persists raw body and etag`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }
        let cache = fixture.makeCache()
        let formulaBody = fixture.analyticsJSON(name: "wget", kind: .formula)
        let caskBody = fixture.analyticsJSON(name: "iterm2", kind: .cask)

        try await cache.updateFormulaAnalytics(window: .days30, with: formulaBody, etag: #""formula-etag""#)
        try await cache.updateCaskAnalytics(window: .days30, with: caskBody, etag: #""cask-etag""#)

        #expect(await cache.formulaAnalyticsData(window: .days30) == formulaBody)
        #expect(await cache.caskAnalyticsData(window: .days30) == caskBody)
        #expect(await cache.etag(for: .formula, window: .days30) == #""formula-etag""#)
        #expect(await cache.etag(for: .cask, window: .days30) == #""cask-etag""#)

        let persisted = try Data(contentsOf: fixture.cacheURL(kind: .formula, window: .days30))
        #expect(persisted == formulaBody)
    }

    @Test @MainActor func `update overwrites previous bytes and etag`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }
        let cache = fixture.makeCache()

        try await cache.updateFormulaAnalytics(
            window: .days30,
            with: fixture.analyticsJSON(name: "stale", kind: .formula),
            etag: #""stale""#,
        )
        let fresh = fixture.analyticsJSON(name: "fresh", kind: .formula)
        try await cache.updateFormulaAnalytics(window: .days30, with: fresh, etag: #""fresh""#)

        #expect(await cache.formulaAnalyticsData(window: .days30) == fresh)
        #expect(await cache.etag(for: .formula, window: .days30) == #""fresh""#)
    }

    @Test @MainActor func `analytics are keyed by window`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }
        let cache = fixture.makeCache()
        let body = fixture.analyticsJSON(name: "wget", kind: .formula)

        try await cache.updateFormulaAnalytics(window: .days30, with: body, etag: nil)

        #expect(await cache.formulaAnalyticsData(window: .days30) == body)
        #expect(await cache.formulaAnalyticsData(window: .days90) == nil)
    }

    @Test @MainActor func `prepare reads analytics persisted by a previous instance`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }

        // First "launch" writes to disk.
        let writer = fixture.makeCache()
        let formulaBody = fixture.analyticsJSON(name: "wget", kind: .formula)
        try await writer.updateFormulaAnalytics(window: .days30, with: formulaBody, etag: #""formula-etag""#)

        // Second "launch": a fresh instance warms itself from the persisted files.
        let reader = fixture.makeCache()
        await reader.prepare()

        #expect(await reader.formulaAnalyticsData(window: .days30) == formulaBody)
        #expect(await reader.etag(for: .formula, window: .days30) == #""formula-etag""#)
    }

    @Test @MainActor func `prepare does not overwrite in memory updates`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }

        try fixture.writeToDisk(
            fixture.analyticsJSON(name: "stale", kind: .formula),
            kind: .formula,
            window: .days30,
        )
        let cache = fixture.makeCache()
        let fresh = fixture.analyticsJSON(name: "fresh", kind: .formula)
        try await cache.updateFormulaAnalytics(window: .days30, with: fresh, etag: nil)

        await cache.prepare()

        #expect(await cache.formulaAnalyticsData(window: .days30) == fresh)
    }
}

@MainActor
private struct TestFixture {
    let cacheDirectoryURL: URL
    let defaultsKeyPrefix: String

    init() {
        let id = UUID().uuidString
        cacheDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiscoverAnalyticsCacheTests-\(id)", isDirectory: true)
        defaultsKeyPrefix = "DiscoverAnalyticsCacheTests.\(id)"
    }

    func makeCache() -> DiscoverAnalyticsCache {
        DiscoverAnalyticsCache(cacheDirectoryURL: cacheDirectoryURL, defaultsKeyPrefix: defaultsKeyPrefix)
    }

    func cacheURL(kind: DiscoverAnalyticsCache.AnalyticsKind, window: BrewAnalyticsWindow) -> URL {
        cacheDirectoryURL.appendingPathComponent("\(kind.rawValue)-analytics-\(window.rawValue).json")
    }

    func writeToDisk(
        _ data: Data,
        kind: DiscoverAnalyticsCache.AnalyticsKind,
        window: BrewAnalyticsWindow,
    ) throws {
        try FileManager.default.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        try data.write(to: cacheURL(kind: kind, window: window), options: .atomic)
    }

    func analyticsJSON(name: String, kind: DiscoverAnalyticsCache.AnalyticsKind) -> Data {
        let key = kind == .formula ? "formula" : "cask"
        return Data(
            """
            {
              "category": "\(kind.rawValue)_install",
              "total_items": 1,
              "total_count": 100,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "\(name)": [{ "number": 1, "\(key)": "\(name)", "count": "100" }]
              }
            }
            """.utf8,
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: cacheDirectoryURL)
        UserDefaults.standard.removePersistedKeys(withPrefix: defaultsKeyPrefix)
    }
}
