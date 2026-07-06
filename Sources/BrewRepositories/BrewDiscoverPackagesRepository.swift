//
//  BrewDiscoverPackagesRepository.swift
//  BrewRepositories
//

import BrewCore
import BrewNetworking
import BrewRepositoryInterfaces
import Foundation

enum DiscoverPackagesRepositoryError: Error, Equatable {
    case cacheMissingAfterRefresh(window: BrewAnalyticsWindow)
}

/// Discover top-package repository with a 24-hour analytics cache.
///
/// Homebrew publishes install analytics once per day, so the raw analytics responses are cached to
/// disk (via ``DiscoverAnalyticsCaching``) and only refetched when older than `ttl`. Staleness is
/// tracked with a per-window `lastRefresh` timestamp in `UserDefaults`, mirroring
/// `BrewCatalogueRepository`. Catalogue enrichment (name/description/version lookups) is re-run on
/// every call from the cached analytics — that path is already cached by the catalogue repository.
public actor BrewDiscoverPackagesRepository: DiscoverPackagesRepository {
    public static let defaultTTL: TimeInterval = 86400

    private let apiClient: any BrewAPIClient
    private let catalogueRepository: any CatalogueRepository
    private let cache: any DiscoverAnalyticsCaching
    private let defaultsKeyPrefix: String
    private let now: @Sendable () -> Date
    private let ttl: TimeInterval

    private var refreshTasks: [BrewAnalyticsWindow: Task<(Data, Data), Error>] = [:]

    /// `defaultsKeyPrefix` is the test seam for `UserDefaults.standard`; tests pass a unique prefix
    /// to isolate their lastRefresh timestamps from each other and from production data.
    public init(
        apiClient: any BrewAPIClient,
        catalogueRepository: any CatalogueRepository,
        cache: any DiscoverAnalyticsCaching,
        defaultsKeyPrefix: String = "DiscoverAnalytics",
        now: @escaping @Sendable () -> Date = Date.init,
        ttl: TimeInterval = BrewDiscoverPackagesRepository.defaultTTL,
    ) {
        self.apiClient = apiClient
        self.catalogueRepository = catalogueRepository
        self.cache = cache
        self.defaultsKeyPrefix = defaultsKeyPrefix
        self.now = now
        self.ttl = ttl
    }

    nonisolated func lastRefreshKey(for window: BrewAnalyticsWindow) -> String {
        "\(defaultsKeyPrefix).analytics.\(window.rawValue).lastRefresh"
    }

    public func loadTopPackages(
        limit: Int = 10,
        window: BrewAnalyticsWindow = .days30,
    ) async throws -> DiscoverTopPackagesSnapshot {
        let (formulaData, caskData) = try await freshAnalyticsData(window: window)
        return try await enrichedSnapshot(formulaData: formulaData, caskData: caskData, limit: limit)
    }

    /// Returns the cached analytics bytes for `window`, refetching over the network only when the
    /// cache is stale or the bytes are unexpectedly absent.
    private func freshAnalyticsData(window: BrewAnalyticsWindow) async throws -> (Data, Data) {
        if !isStale(window: window),
           let formulaData = await cache.formulaAnalyticsData(window: window),
           let caskData = await cache.caskAnalyticsData(window: window)
        {
            return (formulaData, caskData)
        }
        return try await refreshAwaitingSharedTask(for: window)
    }

    /// Coalesces concurrent refreshes for the same window so simultaneous view appearances trigger a
    /// single network round-trip (mirrors `BrewCatalogueRepository.refreshAwaitingSharedTask`).
    private func refreshAwaitingSharedTask(for window: BrewAnalyticsWindow) async throws -> (Data, Data) {
        if let existing = refreshTasks[window] {
            return try await existing.value
        }
        let task = Task { try await self.performRefresh(for: window) }
        refreshTasks[window] = task
        do {
            let value = try await task.value
            refreshTasks[window] = nil
            return value
        } catch {
            refreshTasks[window] = nil
            throw error
        }
    }

    private func performRefresh(for window: BrewAnalyticsWindow) async throws -> (Data, Data) {
        let formulaETag = await cache.etag(for: .formula, window: window)
        let formulaResponse = try await apiClient.fetchFormulaInstallOnRequestAnalytics(
            window: window,
            etag: formulaETag,
        )
        switch formulaResponse {
        case .notModified:
            break
        case let .updated(data: data, etag: nextETag):
            try await cache.updateFormulaAnalytics(window: window, with: data, etag: nextETag)
        }

        let caskETag = await cache.etag(for: .cask, window: window)
        let caskResponse = try await apiClient.fetchCaskInstallAnalytics(window: window, etag: caskETag)
        switch caskResponse {
        case .notModified:
            break
        case let .updated(data: data, etag: nextETag):
            try await cache.updateCaskAnalytics(window: window, with: data, etag: nextETag)
        }

        guard let formulaData = await cache.formulaAnalyticsData(window: window),
              let caskData = await cache.caskAnalyticsData(window: window)
        else {
            throw DiscoverPackagesRepositoryError.cacheMissingAfterRefresh(window: window)
        }

        // Only stamp the cache fresh once both fetches (and stores) succeeded, so a mid-refresh
        // failure leaves the window stale and the next call retries.
        updateLastRefresh(window: window)
        return (formulaData, caskData)
    }

    private func enrichedSnapshot(
        formulaData: Data,
        caskData: Data,
        limit: Int,
    ) async throws -> DiscoverTopPackagesSnapshot {
        let formulaAnalytics = try Self.decodeAnalytics(formulaData)
        let caskAnalytics = try Self.decodeAnalytics(caskData)

        let formulae = try await topPackages(from: formulaAnalytics, limit: limit)
        let casks = try await topPackages(from: caskAnalytics, limit: limit)

        return DiscoverTopPackagesSnapshot(topFormulae: formulae, topCasks: casks)
    }

    private func topPackages(
        from analytics: BrewAnalyticsJSON,
        limit: Int,
    ) async throws -> [DiscoveryBrewPackage] {
        let validatedLimit = max(0, limit)
        guard validatedLimit > 0 else {
            return []
        }

        var results: [DiscoveryBrewPackage] = []
        results.reserveCapacity(validatedLimit)

        let sortedCounts = analytics.packageCounts.sorted(by: sortByInstallCountDescendingThenNameAscending)
        for entry in sortedCounts {
            guard let package = try await catalogueRepository.package(for: entry.reference) else {
                continue
            }
            results.append(
                DiscoveryBrewPackage(
                    package: package,
                    thirtyDayInstallCount: entry.count,
                ),
            )
            if results.count >= validatedLimit {
                break
            }
        }
        return results
    }

    private func sortByInstallCountDescendingThenNameAscending(
        _ lhs: BrewAnalyticsPackageCount,
        _ rhs: BrewAnalyticsPackageCount,
    ) -> Bool {
        if lhs.count == rhs.count {
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return lhs.count > rhs.count
    }

    private func updateLastRefresh(window: BrewAnalyticsWindow) {
        UserDefaults.standard.set(now(), forKey: lastRefreshKey(for: window))
    }

    private func isStale(window: BrewAnalyticsWindow) -> Bool {
        guard let refreshedAt = UserDefaults.standard.object(forKey: lastRefreshKey(for: window)) as? Date else {
            return true
        }
        return now().timeIntervalSince(refreshedAt) >= ttl
    }

    private static func decodeAnalytics(_ data: Data) throws -> BrewAnalyticsJSON {
        try JSONDecoder().decode(BrewAnalyticsJSON.self, from: data)
    }
}
