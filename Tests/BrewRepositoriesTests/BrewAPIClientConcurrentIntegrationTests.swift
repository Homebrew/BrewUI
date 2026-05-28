//
//  BrewAPIClientConcurrentIntegrationTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
import BrewNetworking
import BrewRepositoryInterfaces
@testable import BrewRepositories
import BrewRepositoriesTestSupport
import BrewServicesTestSupport
import Foundation
import Testing

/// Exercises the same shared `URLSessionBrewAPIClient` + concurrent call patterns as Discover.
struct BrewAPIClientConcurrentIntegrationTests {
    @Test @MainActor func `shared client fetches discover analytics concurrently`() async throws {
        let baseURL = makeStubBaseURL()
        let host = try #require(baseURL.host)
        StubURLProtocol.registerByPath(
            [
                "/api/analytics/install-on-request/homebrew-core/30d.json": .formulaAnalyticsStub,
                "/api/analytics/cask-install/homebrew-cask/30d.json": .caskAnalyticsStub,
            ],
            forHost: host,
        )
        let client = makeSharedClient(baseURL: baseURL)
        let repository = try await makeDiscoverRepository(
            apiClient: client,
            formulaCatalogueNames: ["wget"],
            caskCatalogueNames: ["iterm2"],
        )

        let snapshot = try await repository.loadTopPackages(limit: 1, window: .days30)

        #expect(snapshot.topFormulae.first?.reference == .formula(name: "wget"))
        #expect(snapshot.topCasks.first?.reference == .cask(token: "iterm2"))
        #expect(StubURLProtocol.requests(forHost: host).count == 2)
    }

    @Test @MainActor func `shared client fetches both catalogues concurrently`() async throws {
        let baseURL = makeStubBaseURL()
        let host = try #require(baseURL.host)
        StubURLProtocol.registerByPath(
            [
                "/api/formula.json": .formulaCatalogueStub,
                "/api/cask.json": .caskCatalogueStub,
            ],
            forHost: host,
        )
        let client = makeSharedClient(baseURL: baseURL)

        async let formulaResponse = client.fetchFormulaCatalogue(etag: nil)
        async let caskResponse = client.fetchCaskCatalogue(etag: nil)

        let formula = try await formulaResponse
        let cask = try await caskResponse

        guard case let .updated(data: formulaData, _) = formula else {
            Issue.record("Expected formula catalogue payload")
            return
        }
        guard case let .updated(data: caskData, _) = cask else {
            Issue.record("Expected cask catalogue payload")
            return
        }
        #expect(formulaData.items.first?.name == "wget")
        #expect(caskData.items.first?.name == "iterm2")
        #expect(StubURLProtocol.requests(forHost: host).count == 2)
    }

    @Test @MainActor func `shared client runs all four discover endpoints concurrently`() async throws {
        let baseURL = makeStubBaseURL()
        let host = try #require(baseURL.host)
        StubURLProtocol.registerByPath(Self.discoverEndpointStubs, forHost: host)
        let client = makeSharedClient(baseURL: baseURL)

        async let formulaAnalytics = client.fetchFormulaInstallOnRequestAnalytics(window: .days30)
        async let caskAnalytics = client.fetchCaskInstallAnalytics(window: .days30)
        async let formulaCatalogue = client.fetchFormulaCatalogue(etag: nil)
        async let caskCatalogue = client.fetchCaskCatalogue(etag: nil)

        _ = try await formulaAnalytics
        _ = try await caskAnalytics
        _ = try await formulaCatalogue
        _ = try await caskCatalogue

        #expect(StubURLProtocol.requests(forHost: host).count == 4)
    }

    @Test @MainActor func `shared client matches discover view model load overlap`() async throws {
        let baseURL = makeStubBaseURL()
        let host = try #require(baseURL.host)
        StubURLProtocol.registerByPath(Self.discoverEndpointStubs, forHost: host)
        let client = makeSharedClient(baseURL: baseURL)
        let catalogueRepository = try await makeWarmCatalogueRepository(
            apiClient: client,
            formulaNames: ["wget"],
            caskNames: ["iterm2"],
        )
        let discoverRepository = BrewDiscoverPackagesRepository(
            apiClient: client,
            catalogueRepository: catalogueRepository,
        )

        async let topPackagesTask = discoverRepository.loadTopPackages(limit: 1, window: .days30)
        async let formulaCatalogueTask = catalogueRepository.package(for: .formula(name: "wget"))
        async let caskCatalogueTask = catalogueRepository.package(for: .cask(token: "iterm2"))

        let snapshot = try await topPackagesTask
        _ = try await formulaCatalogueTask
        _ = try await caskCatalogueTask

        #expect(snapshot.topFormulae.count == 1)
        #expect(snapshot.topCasks.count == 1)
        #expect(StubURLProtocol.requests(forHost: host).count == 2)
    }

    @Test @MainActor func `shared client survives repeated concurrent discover bursts`() async throws {
        let baseURL = makeStubBaseURL()
        let host = try #require(baseURL.host)
        StubURLProtocol.registerRepeatingByPath(Self.discoverEndpointStubs, forHost: host)
        let client = makeSharedClient(baseURL: baseURL)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 24 {
                group.addTask {
                    async let formulaAnalytics = client.fetchFormulaInstallOnRequestAnalytics(window: .days30)
                    async let caskAnalytics = client.fetchCaskInstallAnalytics(window: .days30)
                    async let formulaCatalogue = client.fetchFormulaCatalogue(etag: nil)
                    async let caskCatalogue = client.fetchCaskCatalogue(etag: nil)
                    _ = try await formulaAnalytics
                    _ = try await caskAnalytics
                    _ = try await formulaCatalogue
                    _ = try await caskCatalogue
                }
            }
            try await group.waitForAll()
        }

        #expect(StubURLProtocol.requests(forHost: host).count == 96)
    }
}

@MainActor
private func makeSharedClient(baseURL: URL) -> URLSessionBrewAPIClient {
    URLSessionBrewAPIClient(session: makeStubbedSession(), baseURL: baseURL)
}

@MainActor
private func makeDiscoverRepository(
    apiClient: URLSessionBrewAPIClient,
    formulaCatalogueNames: [String],
    caskCatalogueNames: [String],
) async throws -> BrewDiscoverPackagesRepository {
    try await BrewDiscoverPackagesRepository(
        apiClient: apiClient,
        catalogueRepository: makeWarmCatalogueRepository(
            apiClient: apiClient,
            formulaNames: formulaCatalogueNames,
            caskNames: caskCatalogueNames,
        ),
    )
}

/// Builds a `BrewCatalogueRepository` whose staleness check considers the catalogue fresh.
/// Uses a per-fixture `defaultsKeyPrefix` so lastRefresh timestamps land under unique keys
/// in `UserDefaults.standard` rather than relying on whatever's left from prior runs.
@MainActor
private func makeWarmCatalogueRepository(
    apiClient: URLSessionBrewAPIClient,
    formulaNames: [String],
    caskNames: [String],
) async throws -> BrewCatalogueRepository {
    let fixture = DiscoverCatalogueCacheFixture()
    let cache = CatalogueCache(
        cacheDirectoryURL: fixture.cacheDirectoryURL,
        defaultsKeyPrefix: fixture.defaultsKeyPrefix,
    )
    let repository = BrewCatalogueRepository(
        apiClient: apiClient,
        cache: cache,
        defaultsKeyPrefix: fixture.defaultsKeyPrefix,
    )
    let now = Date()
    if !formulaNames.isEmpty {
        try await cache.updateFormulaCatalogue(
            with: fixture.formulaCacheJSON(names: formulaNames),
            etag: #""formula-etag""#,
        )
        UserDefaults.standard.set(now, forKey: repository.lastRefreshKey(for: .formula))
    }
    if !caskNames.isEmpty {
        try await cache.updateCaskCatalogue(
            with: fixture.caskCacheJSON(names: caskNames),
            etag: #""cask-etag""#,
        )
        UserDefaults.standard.set(now, forKey: repository.lastRefreshKey(for: .cask))
    }
    return repository
}

@MainActor
private struct DiscoverCatalogueCacheFixture {
    let cacheDirectoryURL: URL
    let defaultsKeyPrefix: String

    init() {
        let id = UUID().uuidString
        cacheDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiscoverCatalogueCacheFixture-\(id)", isDirectory: true)
        defaultsKeyPrefix = "DiscoverCatalogueCacheFixture.\(id)"
    }

    func formulaCacheJSON(names: [String]) -> Data {
        catalogueCacheJSON(
            names: names,
            kindLabel: "Formula",
            stableVersion: "1.0.0",
        )
    }

    func caskCacheJSON(names: [String]) -> Data {
        let items = names.map { name in
            """
              {
                "token": "\(name)",
                "name": ["\(name)"],
                "desc": "Cask \(name)",
                "homepage": "https://example.com/\(name)",
                "version": "2.0.0",
                "depends_on": { "macos": {} }
              }
            """
        }
        return Data("[\n\(items.joined(separator: ",\n"))\n]".utf8)
    }

    private func catalogueCacheJSON(
        names: [String],
        kindLabel: String,
        stableVersion: String,
    ) -> Data {
        let items = names.map { name in
            """
              {
                "name": "\(name)",
                "desc": "\(kindLabel) \(name)",
                "homepage": "https://example.com/\(name)",
                "versions": { "stable": "\(stableVersion)" },
                "dependencies": []
              }
            """
        }
        return Data("[\n\(items.joined(separator: ",\n"))\n]".utf8)
    }
}

private extension BrewAPIClientConcurrentIntegrationTests {
    static let discoverEndpointStubs: [String: StubURLProtocol.StubbedResult] = [
        "/api/analytics/install-on-request/homebrew-core/30d.json": .formulaAnalyticsStub,
        "/api/analytics/cask-install/homebrew-cask/30d.json": .caskAnalyticsStub,
        "/api/formula.json": .formulaCatalogueStub,
        "/api/cask.json": .caskCatalogueStub,
    ]
}

private extension StubURLProtocol.StubbedResult {
    static let formulaAnalyticsStub = Self.successWithStatus(
        data: Data(
            """
            {
              "category": "formula_install_on_request",
              "total_items": 1,
              "total_count": 100,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "wget": [{ "formula": "wget", "count": "100" }]
              }
            }
            """.utf8,
        ),
        statusCode: 200,
    )

    static let caskAnalyticsStub = Self.successWithStatus(
        data: Data(
            """
            {
              "category": "cask_install",
              "total_items": 1,
              "total_count": 50,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "iterm2": [{ "cask": "iterm2", "count": "50" }]
              }
            }
            """.utf8,
        ),
        statusCode: 200,
    )

    static let formulaCatalogueStub = Self.successWithStatus(
        data: Data(
            """
            [
              {
                "name": "wget",
                "desc": "Network downloader",
                "homepage": "https://www.gnu.org/software/wget/",
                "versions": { "stable": "1.24.5" },
                "dependencies": []
              }
            ]
            """.utf8,
        ),
        statusCode: 200,
    )

    static let caskCatalogueStub = Self.successWithStatus(
        data: Data(
            """
            [
              {
                "token": "iterm2",
                "name": ["iTerm2"],
                "desc": "Terminal emulator",
                "homepage": "https://iterm2.com",
                "version": "3.5.0",
                "depends_on": { "macos": {} }
              }
            ]
            """.utf8,
        ),
        statusCode: 200,
    )
}
