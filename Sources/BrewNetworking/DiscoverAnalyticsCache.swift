//
//  DiscoverAnalyticsCache.swift
//  BrewNetworking
//

import BrewCore
import Foundation

/// Persistent store for the raw Homebrew analytics JSON responses that back the Discover trending
/// list. Mirrors ``CatalogueCache``: the network bytes are written verbatim to disk (the
/// `BrewAnalyticsJSON` DTO is lossy/`Decodable`-only, so it cannot be re-encoded), keyed by kind and
/// analytics window, with ETags stored alongside in `UserDefaults`.
public actor DiscoverAnalyticsCache: DiscoverAnalyticsCaching {
    public enum AnalyticsKind: String, Sendable, CaseIterable {
        case formula
        case cask
    }

    private struct CacheKey: Hashable {
        let kind: AnalyticsKind
        let window: BrewAnalyticsWindow
    }

    private let cacheDirectoryURL: URL
    private let defaultsKeyPrefix: String

    private var inMemoryData: [CacheKey: Data] = [:]
    private var hasPrepared = false
    private var prepareTask: Task<[CacheKey: Data], Never>?

    /// `cacheDirectoryURL` and `defaultsKeyPrefix` are the only test seams; the actor reaches for
    /// `FileManager.default` / `UserDefaults.standard` itself so it doesn't have to store
    /// non-Sendable singletons. Tests pass a unique tmp directory + unique key prefix to isolate.
    public init(
        cacheDirectoryURL: URL? = nil,
        defaultsKeyPrefix: String = "DiscoverAnalyticsCache",
    ) {
        self.cacheDirectoryURL = cacheDirectoryURL ?? Self.defaultCacheDirectoryURL()
        self.defaultsKeyPrefix = defaultsKeyPrefix
    }

    public func prepare() async {
        if hasPrepared {
            return
        }

        if let inFlightTask = prepareTask {
            await applyPreparedData(inFlightTask.value)
            hasPrepared = true
            return
        }

        let directoryURL = cacheDirectoryURL
        let task = Task(priority: .utility) {
            var loaded: [CacheKey: Data] = [:]
            for window in BrewAnalyticsWindow.allCases {
                for kind in AnalyticsKind.allCases {
                    let url = Self.cacheURL(in: directoryURL, kind: kind, window: window)
                    if let data = try? Data(contentsOf: url) {
                        loaded[CacheKey(kind: kind, window: window)] = data
                    }
                }
            }
            return loaded
        }
        prepareTask = task
        let loaded = await task.value
        prepareTask = nil
        applyPreparedData(loaded)
        hasPrepared = true
    }

    public func formulaAnalyticsData(window: BrewAnalyticsWindow) async -> Data? {
        inMemoryData[CacheKey(kind: .formula, window: window)]
    }

    public func caskAnalyticsData(window: BrewAnalyticsWindow) async -> Data? {
        inMemoryData[CacheKey(kind: .cask, window: window)]
    }

    public func etag(for kind: AnalyticsKind, window: BrewAnalyticsWindow) async -> String? {
        UserDefaults.standard.string(forKey: etagKey(for: kind, window: window))
    }

    public func updateFormulaAnalytics(window: BrewAnalyticsWindow, with rawData: Data, etag: String?) async throws {
        try store(kind: .formula, window: window, rawData: rawData, etag: etag)
    }

    public func updateCaskAnalytics(window: BrewAnalyticsWindow, with rawData: Data, etag: String?) async throws {
        try store(kind: .cask, window: window, rawData: rawData, etag: etag)
    }

    private func store(kind: AnalyticsKind, window: BrewAnalyticsWindow, rawData: Data, etag: String?) throws {
        let url = Self.cacheURL(in: cacheDirectoryURL, kind: kind, window: window)
        try FileManager.default.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        try rawData.write(to: url, options: .atomic)
        inMemoryData[CacheKey(kind: kind, window: window)] = rawData
        persistETag(etag, for: kind, window: window)
    }

    private func persistETag(_ etag: String?, for kind: AnalyticsKind, window: BrewAnalyticsWindow) {
        let key = etagKey(for: kind, window: window)
        if let etag {
            UserDefaults.standard.set(etag, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func etagKey(for kind: AnalyticsKind, window: BrewAnalyticsWindow) -> String {
        "\(defaultsKeyPrefix).\(kind.rawValue).\(window.rawValue).etag"
    }

    private func applyPreparedData(_ loaded: [CacheKey: Data]) {
        // Never clobber in-memory writes that landed while the disk read was in flight.
        for (key, value) in loaded where inMemoryData[key] == nil {
            inMemoryData[key] = value
        }
    }
}

private extension DiscoverAnalyticsCache {
    static func defaultCacheDirectoryURL() -> URL {
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupportURL.appendingPathComponent("Brew", isDirectory: true)
        }
        return fileManager.temporaryDirectory.appendingPathComponent("Brew", isDirectory: true)
    }

    static func cacheURL(in directoryURL: URL, kind: AnalyticsKind, window: BrewAnalyticsWindow) -> URL {
        directoryURL.appendingPathComponent("\(kind.rawValue)-analytics-\(window.rawValue).json")
    }
}
