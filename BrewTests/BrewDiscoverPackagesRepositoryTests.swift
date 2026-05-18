//
//  BrewDiscoverPackagesRepositoryTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct BrewDiscoverPackagesRepositoryTests {
    @Test @MainActor func `loadTopPackages sorts descending and applies limit`() async throws {
        let formulaAnalytics = try analytics(
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
        let caskAnalytics = try analytics(
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

        let repository = BrewDiscoverPackagesRepository(
            apiClient: MockBrewAPIClient(
                formulaAnalytics: formulaAnalytics,
                caskAnalytics: caskAnalytics,
            ),
        )

        let snapshot = try await repository.loadTopPackages(limit: 2, window: .days30)
        #expect(snapshot.topFormulae == [
            DiscoverTopPackage(reference: .formula(name: "bat"), installCount: 1500),
            DiscoverTopPackage(reference: .formula(name: "wget"), installCount: 500),
        ])
        #expect(snapshot.topCasks == [
            DiscoverTopPackage(reference: .cask(token: "raycast"), installCount: 450),
            DiscoverTopPackage(reference: .cask(token: "iterm2"), installCount: 400),
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
        let repository = BrewDiscoverPackagesRepository(
            apiClient: MockBrewAPIClient(
                formulaAnalytics: formulaAnalytics,
                caskAnalytics: caskAnalytics,
            ),
        )

        let snapshot = try await repository.loadTopPackages(limit: 10, window: .days30)
        #expect(snapshot.topFormulae == [
            DiscoverTopPackage(reference: .formula(name: "alpha"), installCount: 400),
            DiscoverTopPackage(reference: .formula(name: "beta"), installCount: 400),
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
        let repository = BrewDiscoverPackagesRepository(
            apiClient: MockBrewAPIClient(
                formulaAnalytics: analyticsPayload,
                caskAnalytics: analyticsPayload,
            ),
        )

        let snapshot = try await repository.loadTopPackages(limit: 0, window: .days30)
        #expect(snapshot.topFormulae.isEmpty)
        #expect(snapshot.topCasks.isEmpty)
    }

    @Test @MainActor func `loadTopPackages forwards client errors`() async throws {
        let repository = BrewDiscoverPackagesRepository(apiClient: ThrowingBrewAPIClient())
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

private func analytics(from json: String) throws -> BrewAnalyticsJSON {
    try JSONDecoder().decode(BrewAnalyticsJSON.self, from: Data(json.utf8))
}
