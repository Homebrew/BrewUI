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
        let cache = CatalogueCache(
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
            _ = try await repository.package(for: .formula(name: "wget"))
        }
        #expect(await apiClient.formulaCallCount() == 1)
    }

    @Test @MainActor func `stale catalogue refreshes on package lookup`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }

        let cache = CatalogueCache(
            userDefaults: fixture.userDefaults,
            cacheDirectoryURL: fixture.cacheDirectoryURL,
        )
        let staleData = fixture.formulaCacheJSON(
            name: "stale",
            dependencies: ["openssl@3"],
        )
        try await cache.updateFormulaCatalogue(with: staleData, etag: #""etag-stale""#)
        fixture.userDefaults.set(Date(timeIntervalSinceReferenceDate: 0), forKey: fixture.formulaLastRefreshKey)

        let refreshedRawData = fixture.formulaCacheJSON(name: "fresh")
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

        let package = try await repository.package(for: .formula(name: "fresh"))
        #expect(package?.name == "fresh")
        #expect(package?.dependencies == [])
        #expect(await apiClient.formulaCallCount() == 1)
        #expect(await apiClient.recordedFormulaETags() == [#""etag-stale""#])
    }

    @Test @MainActor func `not modified refresh updates last refresh and keeps cached data`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }

        let cache = CatalogueCache(
            userDefaults: fixture.userDefaults,
            cacheDirectoryURL: fixture.cacheDirectoryURL,
        )
        let staleData = fixture.formulaCacheJSON(
            name: "cached",
            dependencies: ["pkg-config", "openssl@3"],
        )
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

        let package = try await repository.package(for: .formula(name: "cached"))
        #expect(package?.name == "cached")
        #expect(package?.dependencies == [.formula(name: "pkg-config"), .formula(name: "openssl@3")])
        #expect(await apiClient.recordedFormulaETags() == [#""etag-current""#])

        let updatedDate = fixture.userDefaults.object(forKey: fixture.formulaLastRefreshKey) as? Date
        #expect((updatedDate ?? .distantPast) > staleDate)
    }

    @Test @MainActor func `concurrent package lookups deduplicate in flight refresh task`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }

        let cache = CatalogueCache(
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

        async let first = repository.package(for: .formula(name: "deduped"))
        async let second = repository.package(for: .formula(name: "deduped"))

        #expect(await waitUntil {
            await apiClient.formulaCallCount() == 1
        })
        let dedupedPayload = try JSONDecoder().decode(
            FormulaCatalogueJSON.self,
            from: fixture.formulaCacheJSON(name: "deduped"),
        )
        await apiClient.resumeFormula(
            with: .updated(
                data: dedupedPayload,
                etag: #""etag-deduped""#,
            ),
        )

        let firstResult = try await first
        let secondResult = try await second
        #expect(firstResult?.name == "deduped")
        #expect(secondResult?.name == "deduped")
        #expect(await apiClient.formulaCallCount() == 1)
    }

    @Test @MainActor func `not modified refresh throws when cache has no formula payload`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }

        let cache = MockCatalogueCache(formulaETag: #""etag-current""#)
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

        do {
            _ = try await repository.package(for: .formula(name: "cached"))
            #expect(Bool(false), "Expected cache-missing error for not-modified response.")
        } catch let error as CatalogueRepositoryError {
            #expect(error == .cacheMissingAfterNotModified(kind: .formula))
        }
        #expect(await apiClient.recordedFormulaETags() == [#""etag-current""#])
    }

    @Test @MainActor func `updated refresh persists through cache protocol`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }

        let cache = MockCatalogueCache(formulaETag: #""etag-prev""#)
        let rawData = fixture.formulaCacheJSON(name: "wget")
        let payload = try JSONDecoder().decode(FormulaCatalogueJSON.self, from: rawData)
        let apiClient = StubCatalogueAPIClient(
            formulaHandler: { _ in
                .updated(data: payload, etag: #""etag-next""#)
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

        let package = try await repository.package(for: .formula(name: "wget"))

        #expect(package?.name == "wget")
        #expect(await apiClient.recordedFormulaETags() == [#""etag-prev""#])
        #expect(await cache.formulaUpdateCount() == 1)
        #expect(await cache.latestFormulaETag() == #""etag-next""#)
        #expect(await cache.formulaCatalogue()?.items.first?.name == "wget")
    }

    @Test @MainActor func `package lookup returns nil when reference is absent from catalogue`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }

        let cache = CatalogueCache(
            userDefaults: fixture.userDefaults,
            cacheDirectoryURL: fixture.cacheDirectoryURL,
        )
        try await cache.updateFormulaCatalogue(
            with: fixture.formulaCacheJSON(name: "wget"),
            etag: #""etag-formula""#,
        )
        fixture.userDefaults.set(Date(), forKey: fixture.formulaLastRefreshKey)

        let apiClient = StubCatalogueAPIClient(
            formulaHandler: { _ in .notModified },
            caskHandler: { _ in .notModified },
        )
        let repository = BrewCatalogueRepository(
            apiClient: apiClient,
            cache: cache,
            userDefaults: fixture.userDefaults,
            now: Date.init,
        )

        let package = try await repository.package(for: .formula(name: "missing"))
        #expect(package == nil)
        #expect(await apiClient.formulaCallCount() == 0)
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

private actor MockCatalogueCache: CatalogueCaching {
    private let decoder = JSONDecoder()
    private var formulaData: FormulaCatalogueJSON?
    private var caskData: CaskCatalogueJSON?
    private var formulaETag: String?
    private var caskETag: String?
    private var formulaUpdates: [(etag: String?, rawData: Data)] = []

    init(
        formulaData: FormulaCatalogueJSON? = nil,
        caskData: CaskCatalogueJSON? = nil,
        formulaETag: String? = nil,
        caskETag: String? = nil,
    ) {
        self.formulaData = formulaData
        self.caskData = caskData
        self.formulaETag = formulaETag
        self.caskETag = caskETag
    }

    func formulaCatalogue() async -> FormulaCatalogueJSON? {
        formulaData
    }

    func caskCatalogue() async -> CaskCatalogueJSON? {
        caskData
    }

    func etag(for kind: CatalogueCache.CatalogueKind) async -> String? {
        switch kind {
        case .formula:
            formulaETag
        case .cask:
            caskETag
        }
    }

    func updateFormulaCatalogue(with rawData: Data, etag: String?) async throws {
        formulaData = try decoder.decode(FormulaCatalogueJSON.self, from: rawData)
        formulaETag = etag
        formulaUpdates.append((etag: etag, rawData: rawData))
    }

    func updateCaskCatalogue(with rawData: Data, etag: String?) async throws {
        caskData = try decoder.decode(CaskCatalogueJSON.self, from: rawData)
        caskETag = etag
    }

    func formulaUpdateCount() -> Int {
        formulaUpdates.count
    }

    func latestFormulaETag() -> String? {
        formulaUpdates.last?.etag
    }
}

private struct TestFixture {
    let cacheDirectoryURL: URL
    let userDefaults: UserDefaults
    let userDefaultsSuiteName: String
    let formulaLastRefreshKey = BrewCatalogueRepository.DefaultsKey.formulaLastRefresh

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

    func formulaCacheJSON(name: String, dependencies: [String] = []) -> Data {
        let dependenciesJSON = dependenciesJSONLiteral(from: dependencies)
        return Data(
            """
            [
              {
                "name": "\(name)",
                "desc": "Formula \(name)",
                "homepage": "https://example.com/\(name)",
                "versions": { "stable": "1.0.0" },
                "dependencies": \(dependenciesJSON)
              }
            ]
            """.utf8,
        )
    }

    private func dependenciesJSONLiteral(from dependencies: [String]) -> String {
        let quoted = dependencies.map { "\"\($0)\"" }.joined(separator: ", ")
        return "[\(quoted)]"
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
