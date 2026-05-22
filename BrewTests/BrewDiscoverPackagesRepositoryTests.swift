//
//  BrewDiscoverPackagesRepositoryTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct BrewDiscoverPackagesRepositoryTests {
    @Test @MainActor func `loadTopPackages sorts descending and applies limit`() async throws {
        let repository = try makeRepository(
            formulaAnalytics: DiscoverAnalyticsFixtures.threeFormulaRanking(),
            caskAnalytics: DiscoverAnalyticsFixtures.threeCaskRanking(),
            formulaCatalogueNames: ["wget", "bat", "fd"],
            caskCatalogueNames: ["iterm2", "raycast", "docker-desktop"],
        )

        let snapshot = try await repository.loadTopPackages(limit: 2, window: .days30)
        #expect(snapshot.topFormulae == [
            discoveryPackage(name: "bat", thirtyDayInstallCount: 1500, latestVersion: "1.0.0"),
            discoveryPackage(name: "wget", thirtyDayInstallCount: 500, latestVersion: "1.0.0"),
        ])
        #expect(snapshot.topCasks == [
            discoveryPackage(
                name: "raycast",
                kind: .cask,
                thirtyDayInstallCount: 450,
                latestVersion: "2.0.0",
            ),
            discoveryPackage(
                name: "iterm2",
                kind: .cask,
                thirtyDayInstallCount: 400,
                latestVersion: "2.0.0",
            ),
        ])
    }

    @Test @MainActor func `loadTopPackages supports string counts and tie break sorting`() async throws {
        let formulaAnalytics = try analytics(
            from: """
            {
              "category": "formula_install_on_request",
              "total_items": "2",
              "total_count": "1,000",
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "alpha": [{ "formula": "alpha", "count": "400" }],
                "beta": [{ "formula": "beta", "count": "400" }]
              }
            }
            """,
        )
        let caskAnalytics = try analytics(
            from: """
            {
              "category": "cask_install",
              "total_items": 1,
              "total_count": 40,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "gamma": [{ "cask": "gamma", "count": "40" }]
              }
            }
            """,
        )
        let repository = makeRepository(
            formulaAnalytics: formulaAnalytics,
            caskAnalytics: caskAnalytics,
            formulaCatalogueNames: ["alpha", "beta"],
            caskCatalogueNames: ["gamma"],
        )

        let snapshot = try await repository.loadTopPackages(limit: 10, window: .days30)
        #expect(snapshot.topFormulae == [
            discoveryPackage(name: "alpha", thirtyDayInstallCount: 400, latestVersion: "1.0.0"),
            discoveryPackage(name: "beta", thirtyDayInstallCount: 400, latestVersion: "1.0.0"),
        ])
    }

    @Test @MainActor func `loadTopPackages excludes analytics entries missing from catalogue`() async throws {
        let repository = try makeRepository(
            formulaAnalytics: DiscoverAnalyticsFixtures.threeFormulaRanking(),
            caskAnalytics: DiscoverAnalyticsFixtures.emptyCask(),
            formulaCatalogueNames: ["bat", "wget"],
            caskCatalogueNames: [],
        )

        let snapshot = try await repository.loadTopPackages(limit: 10, window: .days30)
        #expect(snapshot.topFormulae == [
            discoveryPackage(name: "bat", thirtyDayInstallCount: 1500, latestVersion: "1.0.0"),
            discoveryPackage(name: "wget", thirtyDayInstallCount: 500, latestVersion: "1.0.0"),
        ])
        #expect(snapshot.topCasks.isEmpty)
    }

    @Test @MainActor func `loadTopPackages advances past unmatched analytics to fill limit`() async throws {
        let repository = try makeRepository(
            formulaAnalytics: DiscoverAnalyticsFixtures.formulaRankingWithMissingTopEntry(),
            caskAnalytics: DiscoverAnalyticsFixtures.emptyCask(),
            formulaCatalogueNames: ["bat", "wget"],
            caskCatalogueNames: [],
        )

        let snapshot = try await repository.loadTopPackages(limit: 2, window: .days30)
        #expect(snapshot.topFormulae == [
            discoveryPackage(name: "bat", thirtyDayInstallCount: 1500, latestVersion: "1.0.0"),
            discoveryPackage(name: "wget", thirtyDayInstallCount: 500, latestVersion: "1.0.0"),
        ])
    }

    @Test @MainActor func `loadTopPackages returns empty lists when limit is zero`() async throws {
        let analyticsPayload = try analytics(
            from: """
            {
              "category": "formula_install_on_request",
              "total_items": 1,
              "total_count": 10,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "wget": [{ "formula": "wget", "count": "10" }]
              }
            }
            """,
        )
        let repository = makeRepository(
            formulaAnalytics: analyticsPayload,
            caskAnalytics: analyticsPayload,
            formulaCatalogueNames: ["wget"],
            caskCatalogueNames: ["wget"],
        )

        let snapshot = try await repository.loadTopPackages(limit: 0, window: .days30)
        #expect(snapshot.topFormulae.isEmpty)
        #expect(snapshot.topCasks.isEmpty)
    }

    @Test @MainActor func `loadTopPackages forwards client errors`() async throws {
        let repository = BrewDiscoverPackagesRepository(
            apiClient: ThrowingBrewAPIClient(),
            catalogueRepository: MockCatalogueRepository(formulaCatalogue: [], caskCatalogue: []),
        )
        await #expect(throws: BrewAPIClientError.self) {
            _ = try await repository.loadTopPackages(limit: 10, window: .days30)
        }
    }
}

@MainActor
private struct MockBrewAPIClient: BrewAPIClient {
    let formulaAnalytics: BrewAnalyticsJSON
    let caskAnalytics: BrewAnalyticsJSON

    func fetchFormulaInstallOnRequestAnalytics(window _: BrewAnalyticsWindow) async throws -> BrewAnalyticsJSON {
        formulaAnalytics
    }

    func fetchCaskInstallAnalytics(window _: BrewAnalyticsWindow) async throws -> BrewAnalyticsJSON {
        caskAnalytics
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
}

@MainActor
private struct ThrowingBrewAPIClient: BrewAPIClient {
    func fetchFormulaInstallOnRequestAnalytics(window _: BrewAnalyticsWindow) async throws -> BrewAnalyticsJSON {
        throw BrewAPIClientError.transport(underlying: "offline")
    }

    func fetchCaskInstallAnalytics(window _: BrewAnalyticsWindow) async throws -> BrewAnalyticsJSON {
        throw BrewAPIClientError.transport(underlying: "offline")
    }

    func fetchFormulaCatalogue(etag _: String?) async throws -> CatalogueResponse<FormulaCatalogueJSON> {
        throw BrewAPIClientError.transport(underlying: "offline")
    }

    func fetchCaskCatalogue(etag _: String?) async throws -> CatalogueResponse<CaskCatalogueJSON> {
        throw BrewAPIClientError.transport(underlying: "offline")
    }
}

private enum DiscoverAnalyticsFixtures {
    static func threeFormulaRanking() throws -> BrewAnalyticsJSON {
        try analytics(
            from: """
            {
              "category": "formula_install_on_request",
              "total_items": 3,
              "total_count": 2300,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "wget": [{ "formula": "wget", "count": "500" }],
                "bat": [{ "formula": "bat", "count": "1,500" }],
                "fd": [{ "formula": "fd", "count": "300" }]
              }
            }
            """,
        )
    }

    static func threeCaskRanking() throws -> BrewAnalyticsJSON {
        try analytics(
            from: """
            {
              "category": "cask_install",
              "total_items": 3,
              "total_count": 900,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "iterm2": [{ "cask": "iterm2", "count": "400" }],
                "raycast": [{ "cask": "raycast", "count": "450" }],
                "docker-desktop": [{ "cask": "docker-desktop", "count": "50" }]
              }
            }
            """,
        )
    }

    static func emptyCask() throws -> BrewAnalyticsJSON {
        try analytics(
            from: """
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

    static func formulaRankingWithMissingTopEntry() throws -> BrewAnalyticsJSON {
        try analytics(
            from: """
            {
              "category": "formula_install_on_request",
              "total_items": 3,
              "total_count": 2300,
              "start_date": "2026-04-17",
              "end_date": "2026-05-17",
              "formulae": {
                "missing": [{ "formula": "missing", "count": "2,000" }],
                "bat": [{ "formula": "bat", "count": "1,500" }],
                "wget": [{ "formula": "wget", "count": "500" }]
              }
            }
            """,
        )
    }
}

@MainActor
private func makeRepository(
    formulaAnalytics: BrewAnalyticsJSON,
    caskAnalytics: BrewAnalyticsJSON,
    formulaCatalogueNames: [String],
    caskCatalogueNames: [String],
) -> BrewDiscoverPackagesRepository {
    BrewDiscoverPackagesRepository(
        apiClient: MockBrewAPIClient(
            formulaAnalytics: formulaAnalytics,
            caskAnalytics: caskAnalytics,
        ),
        catalogueRepository: MockCatalogueRepository(
            formulaCatalogue: formulaPackages(names: formulaCatalogueNames),
            caskCatalogue: caskPackages(names: caskCatalogueNames),
        ),
    )
}

private func analytics(from json: String) throws -> BrewAnalyticsJSON {
    try JSONDecoder().decode(BrewAnalyticsJSON.self, from: Data(json.utf8))
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
