//
//  DiscoverAnalyticsCacheDoubles.swift
//  BrewServicesTestSupport
//

import BrewCore
import BrewNetworking
import Foundation

/// In-memory ``DiscoverAnalyticsCaching`` for tests: no disk, no `UserDefaults`. Seed it to simulate
/// an already-populated cache, or leave it empty to force the repository to fetch.
public actor InMemoryDiscoverAnalyticsCache: DiscoverAnalyticsCaching {
    private struct Key: Hashable {
        let kind: DiscoverAnalyticsCache.AnalyticsKind
        let window: BrewAnalyticsWindow
    }

    private var data: [Key: Data] = [:]
    private var etags: [Key: String] = [:]

    public init() {}

    public func seed(
        window: BrewAnalyticsWindow,
        formula: Data,
        cask: Data,
        formulaETag: String? = nil,
        caskETag: String? = nil,
    ) {
        data[Key(kind: .formula, window: window)] = formula
        data[Key(kind: .cask, window: window)] = cask
        etags[Key(kind: .formula, window: window)] = formulaETag
        etags[Key(kind: .cask, window: window)] = caskETag
    }

    public func formulaAnalyticsData(window: BrewAnalyticsWindow) async -> Data? {
        data[Key(kind: .formula, window: window)]
    }

    public func caskAnalyticsData(window: BrewAnalyticsWindow) async -> Data? {
        data[Key(kind: .cask, window: window)]
    }

    public func etag(for kind: DiscoverAnalyticsCache.AnalyticsKind, window: BrewAnalyticsWindow) async -> String? {
        etags[Key(kind: kind, window: window)]
    }

    public func updateFormulaAnalytics(window: BrewAnalyticsWindow, with rawData: Data, etag: String?) async throws {
        data[Key(kind: .formula, window: window)] = rawData
        etags[Key(kind: .formula, window: window)] = etag
    }

    public func updateCaskAnalytics(window: BrewAnalyticsWindow, with rawData: Data, etag: String?) async throws {
        data[Key(kind: .cask, window: window)] = rawData
        etags[Key(kind: .cask, window: window)] = etag
    }
}
