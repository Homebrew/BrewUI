//
//  BrewDiscoverPackagesRepositoryTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
import BrewNetworking
@testable import BrewRepositories
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation
import Testing

struct BrewDiscoverPackagesRepositoryTests {
    // MARK: - Enrichment behaviour

    @Test @MainActor func `load exposes ranked packages and applies limit`() async throws {
        let prefix = uniquePrefix()
        defer { cleanup(prefix) }
        let (repository, _) = makeRepository(
            formulaAnalytics: DiscoverAnalyticsFixtures.threeFormulaRanking(),
            caskAnalytics: DiscoverAnalyticsFixtures.threeCaskRanking(),
            formulaCatalogueNames: ["wget", "bat", "fd"],
            caskCatalogueNames: ["iterm2", "raycast", "docker-desktop"],
            defaultsKeyPrefix: prefix,
            topPackagesLimit: 2,
        )

        await repository.load()

        #expect(try #require(repository.state.value) == [
            discoveryPackage(name: "bat", thirtyDayInstallCount: 1500, latestVersion: "1.0.0"),
            discoveryPackage(name: "wget", thirtyDayInstallCount: 500, latestVersion: "1.0.0"),
            discoveryPackage(name: "raycast", kind: .cask, thirtyDayInstallCount: 450, latestVersion: "2.0.0"),
            discoveryPackage(name: "iterm2", kind: .cask, thirtyDayInstallCount: 400, latestVersion: "2.0.0"),
        ])
    }

    @Test @MainActor func `load parses string counts and honors backend rank`() async throws {
        let prefix = uniquePrefix()
        defer { cleanup(prefix) }
        let formulaAnalytics = analyticsData(
            """
            {
              "category": "formula_install_on_request",
              "total_items": 2,
              "total_count": 1000,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "alpha": [{ "number": 1, "formula": "alpha", "count": "400" }],
                "beta": [{ "number": 2, "formula": "beta", "count": "400" }]
              }
            }
            """,
        )
        let caskAnalytics = analyticsData(
            """
            {
              "category": "cask_install",
              "total_items": 1,
              "total_count": 40,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "gamma": [{ "number": 1, "cask": "gamma", "count": "40" }]
              }
            }
            """,
        )
        let (repository, _) = makeRepository(
            formulaAnalytics: formulaAnalytics,
            caskAnalytics: caskAnalytics,
            formulaCatalogueNames: ["alpha", "beta"],
            caskCatalogueNames: ["gamma"],
            defaultsKeyPrefix: prefix,
        )

        await repository.load()

        #expect(try #require(repository.state.value) == [
            discoveryPackage(name: "alpha", thirtyDayInstallCount: 400, latestVersion: "1.0.0"),
            discoveryPackage(name: "beta", thirtyDayInstallCount: 400, latestVersion: "1.0.0"),
            discoveryPackage(name: "gamma", kind: .cask, thirtyDayInstallCount: 40, latestVersion: "2.0.0"),
        ])
    }

    @Test @MainActor func `load excludes analytics entries missing from catalogue`() async throws {
        let prefix = uniquePrefix()
        defer { cleanup(prefix) }
        let (repository, _) = makeRepository(
            formulaAnalytics: DiscoverAnalyticsFixtures.threeFormulaRanking(),
            caskAnalytics: DiscoverAnalyticsFixtures.emptyCask(),
            formulaCatalogueNames: ["bat", "wget"],
            caskCatalogueNames: [],
            defaultsKeyPrefix: prefix,
        )

        await repository.load()

        #expect(try #require(repository.state.value) == [
            discoveryPackage(name: "bat", thirtyDayInstallCount: 1500, latestVersion: "1.0.0"),
            discoveryPackage(name: "wget", thirtyDayInstallCount: 500, latestVersion: "1.0.0"),
        ])
    }

    @Test @MainActor func `load advances past unmatched analytics to fill limit`() async throws {
        let prefix = uniquePrefix()
        defer { cleanup(prefix) }
        let (repository, _) = makeRepository(
            formulaAnalytics: DiscoverAnalyticsFixtures.formulaRankingWithMissingTopEntry(),
            caskAnalytics: DiscoverAnalyticsFixtures.emptyCask(),
            formulaCatalogueNames: ["bat", "wget"],
            caskCatalogueNames: [],
            defaultsKeyPrefix: prefix,
            topPackagesLimit: 2,
        )

        await repository.load()

        #expect(try #require(repository.state.value) == [
            discoveryPackage(name: "bat", thirtyDayInstallCount: 1500, latestVersion: "1.0.0"),
            discoveryPackage(name: "wget", thirtyDayInstallCount: 500, latestVersion: "1.0.0"),
        ])
    }

    @Test @MainActor func `load returns an empty list when limit is zero`() async throws {
        let prefix = uniquePrefix()
        defer { cleanup(prefix) }
        let analyticsPayload = analyticsData(
            """
            {
              "category": "formula_install_on_request",
              "total_items": 1,
              "total_count": 10,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "wget": [{ "number": 1, "formula": "wget", "count": "10" }]
              }
            }
            """,
        )
        let (repository, _) = makeRepository(
            formulaAnalytics: analyticsPayload,
            caskAnalytics: analyticsPayload,
            formulaCatalogueNames: ["wget"],
            caskCatalogueNames: ["wget"],
            defaultsKeyPrefix: prefix,
            topPackagesLimit: 0,
        )

        await repository.load()

        #expect(try #require(repository.state.value).isEmpty)
    }

    @Test @MainActor func `load surfaces client errors as a failed state`() async {
        let prefix = uniquePrefix()
        defer { cleanup(prefix) }
        let repository = BrewDiscoverPackagesRepository(
            apiClient: ThrowingBrewAPIClient(),
            catalogueRepository: MockCatalogueRepository(formulaCatalogue: [], caskCatalogue: []),
            cache: InMemoryDiscoverAnalyticsCache(),
            defaultsKeyPrefix: prefix,
        )

        await repository.load()

        guard case let .failed(error) = repository.state else {
            Issue.record("expected failed state")
            return
        }
        #expect(error is BrewAPIClientError)
    }

    // MARK: - 24-hour caching

    @Test @MainActor func `second load within ttl serves cache without refetching`() async throws {
        let prefix = uniquePrefix()
        defer { cleanup(prefix) }
        let (repository, spy) = makeRepository(
            formulaAnalytics: DiscoverAnalyticsFixtures.threeFormulaRanking(),
            caskAnalytics: DiscoverAnalyticsFixtures.threeCaskRanking(),
            formulaCatalogueNames: ["bat", "wget", "fd"],
            caskCatalogueNames: ["iterm2", "raycast", "docker-desktop"],
            defaultsKeyPrefix: prefix,
            topPackagesLimit: 2,
        )

        await repository.load()
        let first = try #require(repository.state.value)
        await repository.load()
        let second = try #require(repository.state.value)

        #expect(first == second)
        // One formula + one cask fetch on the cold load; the warm load hits neither endpoint.
        #expect(await spy.analyticsCallCount == 2)
    }

    @Test @MainActor func `pre-seeded fresh cache serves without any network fetch`() async throws {
        let prefix = uniquePrefix()
        defer { cleanup(prefix) }
        let cache = InMemoryDiscoverAnalyticsCache()
        await cache.seed(
            window: .days30,
            formula: DiscoverAnalyticsFixtures.threeFormulaRanking(),
            cask: DiscoverAnalyticsFixtures.emptyCask(),
        )
        let (repository, spy) = makeRepository(
            formulaAnalytics: analyticsData("{}"),
            caskAnalytics: analyticsData("{}"),
            formulaCatalogueNames: ["bat", "wget"],
            caskCatalogueNames: [],
            cache: cache,
            defaultsKeyPrefix: prefix,
            topPackagesLimit: 2,
        )
        markFresh(repository, window: .days30)

        await repository.load()

        #expect(try #require(repository.state.value) == [
            discoveryPackage(name: "bat", thirtyDayInstallCount: 1500, latestVersion: "1.0.0"),
            discoveryPackage(name: "wget", thirtyDayInstallCount: 500, latestVersion: "1.0.0"),
        ])
        #expect(await spy.analyticsCallCount == 0)
    }

    @Test @MainActor func `stale cache refetches and returns fresh analytics`() async throws {
        let prefix = uniquePrefix()
        defer { cleanup(prefix) }
        let cache = InMemoryDiscoverAnalyticsCache()
        // Seed obsolete data and mark the cache stale so the load must refetch.
        await cache.seed(
            window: .days30,
            formula: DiscoverAnalyticsFixtures.formulaRankingWithMissingTopEntry(),
            cask: DiscoverAnalyticsFixtures.emptyCask(),
        )
        let (repository, spy) = makeRepository(
            formulaAnalytics: DiscoverAnalyticsFixtures.threeFormulaRanking(),
            caskAnalytics: DiscoverAnalyticsFixtures.emptyCask(),
            formulaCatalogueNames: ["bat", "wget"],
            caskCatalogueNames: [],
            cache: cache,
            defaultsKeyPrefix: prefix,
            topPackagesLimit: 2,
        )
        markStale(repository, window: .days30)

        await repository.load()

        #expect(try #require(repository.state.value) == [
            discoveryPackage(name: "bat", thirtyDayInstallCount: 1500, latestVersion: "1.0.0"),
            discoveryPackage(name: "wget", thirtyDayInstallCount: 500, latestVersion: "1.0.0"),
        ])
        #expect(await spy.analyticsCallCount == 2)
    }

    @Test @MainActor func `load refetches once the ttl has elapsed`() async {
        let prefix = uniquePrefix()
        defer { cleanup(prefix) }
        let (repository, spy) = makeRepository(
            formulaAnalytics: DiscoverAnalyticsFixtures.threeFormulaRanking(),
            caskAnalytics: DiscoverAnalyticsFixtures.emptyCask(),
            formulaCatalogueNames: ["bat", "wget"],
            caskCatalogueNames: [],
            defaultsKeyPrefix: prefix,
            topPackagesLimit: 2,
        )

        await repository.load()
        #expect(await spy.analyticsCallCount == 2)

        // Simulate more than 24h passing since the last refresh.
        markStale(repository, window: .days30)
        await repository.load()

        #expect(await spy.analyticsCallCount == 4)
    }

    @Test @MainActor func `not modified response reuses cached bytes and refreshes timestamp`() async throws {
        let prefix = uniquePrefix()
        defer { cleanup(prefix) }
        let cache = InMemoryDiscoverAnalyticsCache()
        await cache.seed(
            window: .days30,
            formula: DiscoverAnalyticsFixtures.threeFormulaRanking(),
            cask: DiscoverAnalyticsFixtures.emptyCask(),
            formulaETag: #""formula-e1""#,
            caskETag: #""cask-e1""#,
        )
        let spy = SpyBrewAPIClient(formula: .notModified, cask: .notModified)
        let repository = BrewDiscoverPackagesRepository(
            apiClient: spy,
            catalogueRepository: MockCatalogueRepository(
                formulaCatalogue: formulaPackages(names: ["bat", "wget"]),
                caskCatalogue: [],
            ),
            cache: cache,
            defaultsKeyPrefix: prefix,
            topPackagesLimit: 2,
        )
        markStale(repository, window: .days30)

        await repository.load()

        #expect(try #require(repository.state.value) == [
            discoveryPackage(name: "bat", thirtyDayInstallCount: 1500, latestVersion: "1.0.0"),
            discoveryPackage(name: "wget", thirtyDayInstallCount: 500, latestVersion: "1.0.0"),
        ])
        // Both endpoints were queried conditionally, forwarding the cached ETag...
        #expect(await spy.analyticsCallCount == 2)
        #expect(await spy.receivedFormulaETags == [#""formula-e1""#])
        // ...and the refreshed timestamp means the next load serves from cache with no fetch.
        await repository.load()
        #expect(await spy.analyticsCallCount == 2)
    }

    @Test @MainActor func `analytics error is not cached and next load retries`() async throws {
        let prefix = uniquePrefix()
        defer { cleanup(prefix) }
        let (repository, spy) = makeRepository(
            formulaAnalytics: DiscoverAnalyticsFixtures.threeFormulaRanking(),
            caskAnalytics: DiscoverAnalyticsFixtures.emptyCask(),
            formulaCatalogueNames: ["bat", "wget"],
            caskCatalogueNames: [],
            defaultsKeyPrefix: prefix,
            topPackagesLimit: 2,
            pendingError: BrewAPIClientError.transport(underlying: "offline"),
        )

        await repository.load()
        guard case .failed = repository.state else {
            Issue.record("expected failed state after the first load")
            return
        }

        // The failed attempt left the window stale, so a second load retries and succeeds.
        await repository.load()
        #expect(try #require(repository.state.value) == [
            discoveryPackage(name: "bat", thirtyDayInstallCount: 1500, latestVersion: "1.0.0"),
            discoveryPackage(name: "wget", thirtyDayInstallCount: 500, latestVersion: "1.0.0"),
        ])
        #expect(await spy.formulaCallCount == 2)
    }

    @Test @MainActor func `concurrent loads coalesce into a single refresh`() async throws {
        let prefix = uniquePrefix()
        defer { cleanup(prefix) }
        let (repository, spy) = makeRepository(
            formulaAnalytics: DiscoverAnalyticsFixtures.threeFormulaRanking(),
            caskAnalytics: DiscoverAnalyticsFixtures.threeCaskRanking(),
            formulaCatalogueNames: ["bat", "wget", "fd"],
            caskCatalogueNames: ["iterm2", "raycast", "docker-desktop"],
            defaultsKeyPrefix: prefix,
            topPackagesLimit: 2,
        )

        async let first: Void = repository.load()
        async let second: Void = repository.load()
        _ = await (first, second)

        #expect(try #require(repository.state.value) == [
            discoveryPackage(name: "bat", thirtyDayInstallCount: 1500, latestVersion: "1.0.0"),
            discoveryPackage(name: "wget", thirtyDayInstallCount: 500, latestVersion: "1.0.0"),
            discoveryPackage(name: "raycast", kind: .cask, thirtyDayInstallCount: 450, latestVersion: "2.0.0"),
            discoveryPackage(name: "iterm2", kind: .cask, thirtyDayInstallCount: 400, latestVersion: "2.0.0"),
        ])
        #expect(await spy.analyticsCallCount == 2)
    }

    // MARK: - Cross-launch persistence (integration)

    @Test @MainActor func `analytics persist across relaunch and refetch after ttl`() async throws {
        let fixture = DiscoverAnalyticsDiskFixture()
        defer { fixture.cleanup() }

        // First launch: cold cache, fetch and persist to disk.
        let firstCache = DiscoverAnalyticsCache(
            cacheDirectoryURL: fixture.cacheDirectoryURL,
            defaultsKeyPrefix: fixture.cacheDefaultsPrefix,
        )
        let (firstRepository, firstSpy) = makeRepository(
            formulaAnalytics: DiscoverAnalyticsFixtures.threeFormulaRanking(),
            caskAnalytics: DiscoverAnalyticsFixtures.emptyCask(),
            formulaCatalogueNames: ["bat", "wget"],
            caskCatalogueNames: [],
            cache: firstCache,
            defaultsKeyPrefix: fixture.repositoryDefaultsPrefix,
            topPackagesLimit: 2,
        )
        await firstRepository.load()
        let firstPackages = try #require(firstRepository.state.value)
        #expect(await firstSpy.analyticsCallCount == 2)

        // Second launch: a brand-new cache instance reads the persisted bytes from disk.
        let secondCache = DiscoverAnalyticsCache(
            cacheDirectoryURL: fixture.cacheDirectoryURL,
            defaultsKeyPrefix: fixture.cacheDefaultsPrefix,
        )
        await secondCache.prepare()
        let (secondRepository, secondSpy) = makeRepository(
            formulaAnalytics: DiscoverAnalyticsFixtures.threeFormulaRanking(),
            caskAnalytics: DiscoverAnalyticsFixtures.emptyCask(),
            formulaCatalogueNames: ["bat", "wget"],
            caskCatalogueNames: [],
            cache: secondCache,
            defaultsKeyPrefix: fixture.repositoryDefaultsPrefix,
            topPackagesLimit: 2,
        )
        await secondRepository.load()
        #expect(try #require(secondRepository.state.value) == firstPackages)
        #expect(await secondSpy.analyticsCallCount == 0)

        // Once 24h has elapsed, the relaunched repository refetches.
        markStale(secondRepository, window: .days30)
        await secondRepository.load()
        #expect(await secondSpy.analyticsCallCount == 2)
    }
}

// MARK: - Test doubles

private actor SpyBrewAPIClient: BrewAPIClient {
    private var formulaResponse: CatalogueResponse<Data>
    private var caskResponse: CatalogueResponse<Data>
    private var pendingError: (any Error)?
    private(set) var formulaCallCount = 0
    private(set) var caskCallCount = 0
    private(set) var receivedFormulaETags: [String?] = []

    init(
        formula: CatalogueResponse<Data>,
        cask: CatalogueResponse<Data>,
        pendingError: (any Error)? = nil,
    ) {
        formulaResponse = formula
        caskResponse = cask
        self.pendingError = pendingError
    }

    var analyticsCallCount: Int {
        formulaCallCount + caskCallCount
    }

    func fetchFormulaInstallOnRequestAnalytics(
        window _: BrewAnalyticsWindow,
        etag: String?,
    ) async throws -> CatalogueResponse<Data> {
        formulaCallCount += 1
        receivedFormulaETags.append(etag)
        if let pendingError {
            self.pendingError = nil
            throw pendingError
        }
        return formulaResponse
    }

    func fetchCaskInstallAnalytics(
        window _: BrewAnalyticsWindow,
        etag _: String?,
    ) async throws -> CatalogueResponse<Data> {
        caskCallCount += 1
        return caskResponse
    }

    func fetchFormulaCatalogue(etag _: String?) async throws -> CatalogueResponse<FormulaCatalogueJSON> {
        .notModified
    }

    func fetchCaskCatalogue(etag _: String?) async throws -> CatalogueResponse<CaskCatalogueJSON> {
        .notModified
    }
}

@MainActor
private struct MockCatalogueRepository: CatalogueRepository {
    private let formulaCatalogueByID: [BrewPackage.ID: BrewPackage]
    private let caskCatalogueByID: [BrewPackage.ID: BrewPackage]

    init(formulaCatalogue: [BrewPackage], caskCatalogue: [BrewPackage]) {
        formulaCatalogueByID = Dictionary(uniqueKeysWithValues: formulaCatalogue.map { ($0.id, $0) })
        caskCatalogueByID = Dictionary(uniqueKeysWithValues: caskCatalogue.map { ($0.id, $0) })
    }

    func package(for reference: HomebrewPackageID) async throws -> BrewPackage? {
        switch reference.kind {
        case .formula:
            formulaCatalogueByID[reference]
        case .cask:
            caskCatalogueByID[reference]
        }
    }

    func searchPackages(matching query: String, limit: Int) async throws -> [BrewPackage] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, limit > 0 else {
            return []
        }
        let all = Array(formulaCatalogueByID.values) + Array(caskCatalogueByID.values)
        let matches = all
            .filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return Array(matches.prefix(limit))
    }
}

@MainActor
private struct ThrowingBrewAPIClient: BrewAPIClient {
    func fetchFormulaInstallOnRequestAnalytics(
        window _: BrewAnalyticsWindow,
        etag _: String?,
    ) async throws -> CatalogueResponse<Data> {
        throw BrewAPIClientError.transport(underlying: "offline")
    }

    func fetchCaskInstallAnalytics(
        window _: BrewAnalyticsWindow,
        etag _: String?,
    ) async throws -> CatalogueResponse<Data> {
        throw BrewAPIClientError.transport(underlying: "offline")
    }

    func fetchFormulaCatalogue(etag _: String?) async throws -> CatalogueResponse<FormulaCatalogueJSON> {
        throw BrewAPIClientError.transport(underlying: "offline")
    }

    func fetchCaskCatalogue(etag _: String?) async throws -> CatalogueResponse<CaskCatalogueJSON> {
        throw BrewAPIClientError.transport(underlying: "offline")
    }
}

// MARK: - Fixtures & helpers

private enum DiscoverAnalyticsFixtures {
    static func threeFormulaRanking() -> Data {
        analyticsData(
            """
            {
              "category": "formula_install_on_request",
              "total_items": 3,
              "total_count": 2300,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "wget": [{ "number": 2, "formula": "wget", "count": "500" }],
                "bat": [{ "number": 1, "formula": "bat", "count": "1,500" }],
                "fd": [{ "number": 3, "formula": "fd", "count": "300" }]
              }
            }
            """,
        )
    }

    static func threeCaskRanking() -> Data {
        analyticsData(
            """
            {
              "category": "cask_install",
              "total_items": 3,
              "total_count": 900,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "iterm2": [{ "number": 2, "cask": "iterm2", "count": "400" }],
                "raycast": [{ "number": 1, "cask": "raycast", "count": "450" }],
                "docker-desktop": [{ "number": 3, "cask": "docker-desktop", "count": "50" }]
              }
            }
            """,
        )
    }

    static func emptyCask() -> Data {
        analyticsData(
            """
            {
              "category": "cask_install",
              "total_items": 0,
              "total_count": 0,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {}
            }
            """,
        )
    }

    static func formulaRankingWithMissingTopEntry() -> Data {
        analyticsData(
            """
            {
              "category": "formula_install_on_request",
              "total_items": 3,
              "total_count": 2300,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "missing": [{ "number": 1, "formula": "missing", "count": "2,000" }],
                "bat": [{ "number": 2, "formula": "bat", "count": "1,500" }],
                "wget": [{ "number": 3, "formula": "wget", "count": "500" }]
              }
            }
            """,
        )
    }
}

private func analyticsData(_ json: String) -> Data {
    Data(json.utf8)
}

@MainActor
private func makeRepository(
    formulaAnalytics: Data,
    caskAnalytics: Data,
    formulaCatalogueNames: [String],
    caskCatalogueNames: [String],
    cache: any DiscoverAnalyticsCaching = InMemoryDiscoverAnalyticsCache(),
    defaultsKeyPrefix: String,
    topPackagesLimit: Int = 10,
    pendingError: (any Error)? = nil,
) -> (BrewDiscoverPackagesRepository, SpyBrewAPIClient) {
    let spy = SpyBrewAPIClient(
        formula: .updated(data: formulaAnalytics, etag: nil),
        cask: .updated(data: caskAnalytics, etag: nil),
        pendingError: pendingError,
    )
    let repository = BrewDiscoverPackagesRepository(
        apiClient: spy,
        catalogueRepository: MockCatalogueRepository(
            formulaCatalogue: formulaPackages(names: formulaCatalogueNames),
            caskCatalogue: caskPackages(names: caskCatalogueNames),
        ),
        cache: cache,
        defaultsKeyPrefix: defaultsKeyPrefix,
        topPackagesLimit: topPackagesLimit,
    )
    return (repository, spy)
}

private func uniquePrefix() -> String {
    "DiscoverAnalyticsTests.\(UUID().uuidString)"
}

private func cleanup(_ prefix: String) {
    UserDefaults.standard.removePersistedKeys(withPrefix: prefix)
}

/// Marks a window fresh by stamping its lastRefresh timestamp to now.
private func markFresh(_ repository: BrewDiscoverPackagesRepository, window: BrewAnalyticsWindow) {
    UserDefaults.standard.set(Date(), forKey: repository.lastRefreshKey(for: window))
}

/// Marks a window stale by backdating its lastRefresh timestamp well beyond the 24h TTL.
private func markStale(_ repository: BrewDiscoverPackagesRepository, window: BrewAnalyticsWindow) {
    UserDefaults.standard.set(
        Date(timeIntervalSinceNow: -(BrewDiscoverPackagesRepository.defaultTTL + 3600)),
        forKey: repository.lastRefreshKey(for: window),
    )
}

private func formulaPackages(names: [String]) -> [BrewPackage] {
    names.map { name in
        BrewPackage(
            name: name,
            displayName: name,
            kind: .formula,
            description: "Formula \(name)",
            homepage: "https://example.com/\(name)",
            latestVersion: "1.0.0",
            dependencies: [],
        )
    }
}

private func caskPackages(names: [String]) -> [BrewPackage] {
    names.map { name in
        BrewPackage(
            name: name,
            displayName: name,
            kind: .cask,
            description: "Cask \(name)",
            homepage: "https://example.com/\(name)",
            latestVersion: "2.0.0",
            dependencies: [],
        )
    }
}

private func discoveryPackage(
    name: String,
    kind: HomebrewPackageKind = .formula,
    thirtyDayInstallCount: Int,
    latestVersion: String,
) -> DiscoveryBrewPackage {
    let stableVersionLabel = kind == .formula ? "Formula" : "Cask"
    return DiscoveryBrewPackage(
        package: BrewPackage(
            name: name,
            displayName: name,
            kind: kind,
            description: "\(stableVersionLabel) \(name)",
            homepage: "https://example.com/\(name)",
            latestVersion: latestVersion,
            dependencies: [],
        ),
        thirtyDayInstallCount: thirtyDayInstallCount,
    )
}

@MainActor
private struct DiscoverAnalyticsDiskFixture {
    let cacheDirectoryURL: URL
    let cacheDefaultsPrefix: String
    let repositoryDefaultsPrefix: String

    init() {
        let id = UUID().uuidString
        cacheDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiscoverAnalyticsCacheFixture-\(id)", isDirectory: true)
        cacheDefaultsPrefix = "DiscoverAnalyticsCacheFixture.\(id)"
        repositoryDefaultsPrefix = "DiscoverAnalyticsRepositoryFixture.\(id)"
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: cacheDirectoryURL)
        UserDefaults.standard.removePersistedKeys(withPrefix: cacheDefaultsPrefix)
        UserDefaults.standard.removePersistedKeys(withPrefix: repositoryDefaultsPrefix)
    }
}
