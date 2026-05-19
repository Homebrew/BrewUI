//
//  BrewCatalogueRepositoryTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct BrewCatalogueRepositoryTests {
    @Test @MainActor func `cold start surfaces fetch errors`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }
        let apiClient = StubCatalogueAPIClient(
            formulaHandler: { _ in throw BrewAPIClientError.transport(underlying: "offline") },
            caskHandler: { _ in .notModified },
        )
        let cache = await CatalogueCache(
            userDefaults: fixture.userDefaults,
            cacheDirectoryURL: fixture.cacheDirectoryURL,
        )
        let repository = BrewCatalogueRepository(
            apiClient: apiClient,
            cache: cache,
            userDefaults: fixture.userDefaults,
            now: Date.init,
        )

        await #expect(throws: BrewAPIClientError.self) {
            _ = try await repository.loadFormulaCatalogue()
        }
        #expect(await apiClient.formulaCallCount() == 1)
    }

    @Test @MainActor func `stale formula returns cached value and refreshes in background`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }

        let cache = await CatalogueCache(
            userDefaults: fixture.userDefaults,
            cacheDirectoryURL: fixture.cacheDirectoryURL,
        )
        let staleData = fixture.formulaCacheJSON(name: "stale", installs: 123)
        try await cache.updateFormulaCatalogue(with: staleData, etag: #""etag-stale""#)
        fixture.userDefaults.set(Date(timeIntervalSinceReferenceDate: 0), forKey: fixture.formulaLastRefreshKey)

        let refreshedRawData = fixture.formulaCacheJSON(name: "fresh", installs: 999)
        let refreshedPayload = try JSONDecoder().decode(FormulaCatalogueJSON.self, from: refreshedRawData)
        let apiClient = StubCatalogueAPIClient(
            formulaHandler: { _ in
                try await Task.sleep(nanoseconds: 100_000_000)
                return .updated(data: refreshedPayload, etag: #""etag-fresh""#)
            },
            caskHandler: { _ in .notModified },
        )
        let repository = BrewCatalogueRepository(
            apiClient: apiClient,
            cache: cache,
            userDefaults: fixture.userDefaults,
            now: Date.init,
            ttl: 60,
        )

        let first = try await repository.loadFormulaCatalogue()
        #expect(first.items.first?.name == "stale")

        #expect(await waitUntil {
            await apiClient.formulaCallCount() == 1
        })
        #expect(await waitUntil {
            let latest = try await repository.loadFormulaCatalogue()
            return latest.items.first?.name == "fresh"
        })
        let etags = await apiClient.recordedFormulaETags()
        #expect(etags.first == #""etag-stale""#)
        #expect(!etags.isEmpty)
    }

    @Test @MainActor func `not modified refresh updates last refresh and keeps cached data`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }

        let cache = await CatalogueCache(
            userDefaults: fixture.userDefaults,
            cacheDirectoryURL: fixture.cacheDirectoryURL,
        )
        let staleData = fixture.formulaCacheJSON(name: "cached", installs: 5)
        try await cache.updateFormulaCatalogue(with: staleData, etag: #""etag-current""#)
        let staleDate = Date(timeIntervalSinceReferenceDate: 0)
        fixture.userDefaults.set(staleDate, forKey: fixture.formulaLastRefreshKey)

        let apiClient = StubCatalogueAPIClient(
            formulaHandler: { _ in .notModified },
            caskHandler: { _ in .notModified },
        )
        let repository = BrewCatalogueRepository(
            apiClient: apiClient,
            cache: cache,
            userDefaults: fixture.userDefaults,
            now: Date.init,
            ttl: 60,
        )

        let refreshed = try await repository.loadFormulaCatalogue(forceRefresh: true)
        #expect(refreshed.items.first?.name == "cached")
        #expect(await apiClient.recordedFormulaETags() == [#""etag-current""#])

        let updatedDate = fixture.userDefaults.object(forKey: fixture.formulaLastRefreshKey) as? Date
        #expect((updatedDate ?? .distantPast) > staleDate)
    }

    @Test @MainActor func `force refresh deduplicates in flight request task`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }

        let cache = await CatalogueCache(
            userDefaults: fixture.userDefaults,
            cacheDirectoryURL: fixture.cacheDirectoryURL,
        )
        let apiClient = DeferredFormulaStubCatalogueAPIClient()
        let repository = BrewCatalogueRepository(
            apiClient: apiClient,
            cache: cache,
            userDefaults: fixture.userDefaults,
            now: Date.init,
        )

        async let first = repository.loadFormulaCatalogue(forceRefresh: true)
        async let second = repository.loadFormulaCatalogue(forceRefresh: true)

        #expect(await waitUntil {
            await apiClient.formulaCallCount() == 1
        })
        let dedupedPayload = try JSONDecoder().decode(
            FormulaCatalogueJSON.self,
            from: fixture.formulaCacheJSON(name: "deduped", installs: 99),
        )
        await apiClient.resumeFormula(
            with: .updated(
                data: dedupedPayload,
                etag: #""etag-deduped""#,
            ),
        )

        let firstResult = try await first
        let secondResult = try await second
        #expect(firstResult.items.first?.name == "deduped")
        #expect(secondResult.items.first?.name == "deduped")
        #expect(await apiClient.formulaCallCount() == 1)
    }
}

private actor StubCatalogueAPIClient: BrewAPIClient {
    typealias FormulaHandler = @Sendable (String?) async throws -> CatalogueResponse<FormulaCatalogueJSON>
    typealias CaskHandler = @Sendable (String?) async throws -> CatalogueResponse<CaskCatalogueJSON>

    private let formulaHandler: FormulaHandler
    private let caskHandler: CaskHandler
    private var formulaETags: [String?] = []

    init(formulaHandler: @escaping FormulaHandler, caskHandler: @escaping CaskHandler) {
        self.formulaHandler = formulaHandler
        self.caskHandler = caskHandler
    }

    func fetchFormulaInstallOnRequestAnalytics(window _: BrewAnalyticsWindow) async throws -> BrewAnalyticsJSON {
        throw BrewAPIClientError.invalidResponse
    }

    func fetchCaskInstallAnalytics(window _: BrewAnalyticsWindow) async throws -> BrewAnalyticsJSON {
        throw BrewAPIClientError.invalidResponse
    }

    func fetchFormulaCatalogue(etag: String?) async throws -> CatalogueResponse<FormulaCatalogueJSON> {
        formulaETags.append(etag)
        return try await formulaHandler(etag)
    }

    func fetchCaskCatalogue(etag: String?) async throws -> CatalogueResponse<CaskCatalogueJSON> {
        try await caskHandler(etag)
    }

    func formulaCallCount() -> Int {
        formulaETags.count
    }

    func recordedFormulaETags() -> [String?] {
        formulaETags
    }
}

private actor DeferredFormulaStubCatalogueAPIClient: BrewAPIClient {
    private var formulaETags: [String?] = []
    private var continuation: CheckedContinuation<CatalogueResponse<FormulaCatalogueJSON>, Error>?

    func fetchFormulaInstallOnRequestAnalytics(window _: BrewAnalyticsWindow) async throws -> BrewAnalyticsJSON {
        throw BrewAPIClientError.invalidResponse
    }

    func fetchCaskInstallAnalytics(window _: BrewAnalyticsWindow) async throws -> BrewAnalyticsJSON {
        throw BrewAPIClientError.invalidResponse
    }

    func fetchFormulaCatalogue(etag: String?) async throws -> CatalogueResponse<FormulaCatalogueJSON> {
        formulaETags.append(etag)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func fetchCaskCatalogue(etag _: String?) async throws -> CatalogueResponse<CaskCatalogueJSON> {
        .notModified
    }

    func formulaCallCount() -> Int {
        formulaETags.count
    }

    func resumeFormula(with response: CatalogueResponse<FormulaCatalogueJSON>) {
        continuation?.resume(returning: response)
        continuation = nil
    }
}

private struct TestFixture {
    let cacheDirectoryURL: URL
    let userDefaults: UserDefaults
    let userDefaultsSuiteName: String
    let formulaLastRefreshKey = "CatalogueRepository.formula.lastRefresh"

    init() {
        let id = UUID().uuidString
        cacheDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrewCatalogueRepositoryTests-\(id)", isDirectory: true)
        userDefaultsSuiteName = "BrewCatalogueRepositoryTests.\(id)"
        userDefaults = UserDefaults(suiteName: userDefaultsSuiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: cacheDirectoryURL)
        userDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
    }

    func formulaCacheJSON(name: String, installs: Int) -> Data {
        Data(
            """
            [
              {
                "name": "\(name)",
                "desc": "Formula \(name)",
                "homepage": "https://example.com/\(name)",
                "versions": { "stable": "1.0.0" },
                "analytics": { "install": { "30d": \(installs) } }
              }
            ]
            """.utf8,
        )
    }
}

private func waitUntil(
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    pollNanoseconds: UInt64 = 20_000_000,
    condition: @escaping @Sendable () async throws -> Bool,
) async -> Bool {
    let start = DispatchTime.now().uptimeNanoseconds
    while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
        let matches = try? await condition()
        if matches == true {
            return true
        }
        try? await Task.sleep(nanoseconds: pollNanoseconds)
    }
    return false
}
