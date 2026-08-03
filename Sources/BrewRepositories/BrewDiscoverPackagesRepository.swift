//
//  BrewDiscoverPackagesRepository.swift
//  BrewRepositories
//

import BrewCore
import BrewNetworking
import BrewRepositoryInterfaces
import Foundation
import Observation
import OSLog

private let discoverRepositoryLogger = Logger(
    subsystem: "Homebrew.BrewUI",
    category: "BrewDiscoverPackagesRepository",
)

enum DiscoverPackagesRepositoryError: Error, Equatable {
    case cacheMissingAfterRefresh(window: BrewAnalyticsWindow)
}

/// App-scoped observable source of truth for Discover's trending list, injected into the environment
/// and preloaded at launch. Homebrew publishes install analytics once a day, so raw responses are
/// cached to disk (via ``DiscoverAnalyticsCaching``) and only refetched past `ttl`; the enriched list
/// lives in ``state`` for the session. Mirrors ``BrewInstalledPackagesRepository``.
@Observable
@MainActor
public final class BrewDiscoverPackagesRepository: DiscoverPackagesRepository {
    public static let defaultTTL: TimeInterval = 86400

    /// Carries the underlying `Error` on failure; presentation maps it to copy. Prior loaded data stays
    /// put when a revalidation fails.
    public private(set) var state: LoadState<[DiscoveryBrewPackage], any Error> = .loading

    @ObservationIgnored private let apiClient: any BrewAPIClient
    @ObservationIgnored private let catalogueRepository: any CatalogueRepository
    @ObservationIgnored private let cache: any DiscoverAnalyticsCaching
    @ObservationIgnored private let defaultsKeyPrefix: String
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let ttl: TimeInterval
    @ObservationIgnored private let topPackagesLimit: Int
    @ObservationIgnored private let analyticsWindow: BrewAnalyticsWindow
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    /// `defaultsKeyPrefix` namespaces lastRefresh timestamps in `UserDefaults.standard` so tests isolate.
    public init(
        apiClient: any BrewAPIClient,
        catalogueRepository: any CatalogueRepository,
        cache: any DiscoverAnalyticsCaching,
        defaultsKeyPrefix: String = "DiscoverAnalytics",
        now: @escaping @Sendable () -> Date = Date.init,
        ttl: TimeInterval = BrewDiscoverPackagesRepository.defaultTTL,
        topPackagesLimit: Int = 10,
        analyticsWindow: BrewAnalyticsWindow = .days30,
    ) {
        self.apiClient = apiClient
        self.catalogueRepository = catalogueRepository
        self.cache = cache
        self.defaultsKeyPrefix = defaultsKeyPrefix
        self.now = now
        self.ttl = ttl
        self.topPackagesLimit = topPackagesLimit
        self.analyticsWindow = analyticsWindow
    }

    nonisolated func lastRefreshKey(for window: BrewAnalyticsWindow) -> String {
        "\(defaultsKeyPrefix).analytics.\(window.rawValue).lastRefresh"
    }

    // MARK: - Lifecycle

    /// Cache-first: fresh in-memory data returns instantly; stale/empty/failed state fetches. A single
    /// `loadTask` coalesces concurrent callers (e.g. launch preload and tab on-appear) into one fetch.
    public func load(forceRefresh: Bool) async {
        if !forceRefresh, case .loaded = state, !isStale(window: analyticsWindow) {
            return
        }
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await self.refresh() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func refresh() async {
        // Keep any existing list on screen while revalidating; only show loading with nothing to show.
        if case .loaded = state {} else {
            state = .loading
        }
        do {
            state = try await .loaded(fetchTopPackages())
        } catch is CancellationError {
            return
        } catch {
            // Keep showing cached data if we have any; only surface an error with nothing to show.
            if case .loaded = state {
                discoverRepositoryLogger.error(
                    "Discover trending revalidation failed: \(error.localizedDescription, privacy: .public)",
                )
            } else {
                state = .failed(error)
            }
        }
    }

    // MARK: - Fetch / enrichment

    private func fetchTopPackages() async throws -> [DiscoveryBrewPackage] {
        let (formulaData, caskData) = try await freshAnalyticsData(window: analyticsWindow)
        let formulae = try await topPackages(from: Self.decodeAnalytics(formulaData), limit: topPackagesLimit)
        let casks = try await topPackages(from: Self.decodeAnalytics(caskData), limit: topPackagesLimit)
        return formulae + casks
    }

    private func freshAnalyticsData(window: BrewAnalyticsWindow) async throws -> (Data, Data) {
        if !isStale(window: window),
           let formulaData = await cache.formulaAnalyticsData(window: window),
           let caskData = await cache.caskAnalyticsData(window: window)
        {
            return (formulaData, caskData)
        }
        return try await performRefresh(for: window)
    }

    private func performRefresh(for window: BrewAnalyticsWindow) async throws -> (Data, Data) {
        let formulaETag = await cache.etag(for: .formula, window: window)
        let caskETag = await cache.etag(for: .cask, window: window)

        async let formulaResponse = apiClient.fetchFormulaInstallOnRequestAnalytics(
            window: window,
            etag: formulaETag,
        )
        async let caskResponse = apiClient.fetchCaskInstallAnalytics(
            window: window,
            etag: caskETag,
        )

        switch try await formulaResponse {
        case .notModified:
            break
        case let .updated(data: data, etag: nextETag):
            try await cache.updateFormulaAnalytics(window: window, with: data, etag: nextETag)
        }

        switch try await caskResponse {
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

        // Already ranked; enrich in order and stop once we hit the limit.
        for entry in try analytics.rankedPackageCounts() {
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
