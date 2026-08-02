//
//  DiscoverTrendingIntegrationTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureDiscover
import BrewNetworking
@testable import BrewRepositories
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation
import Testing

/// End-to-end coverage from `DiscoverViewModel` down through the real `BrewDiscoverPackagesRepository`,
/// decoding a payload shaped like the live Homebrew analytics API. This guards the seam that broke once:
/// the API keys entries by package name (alphabetically), the objects carry only `formula`/`cask` +
/// `count` (a comma-grouped string, and **no** rank field), so ranking must be derived from `count`.
struct DiscoverTrendingIntegrationTests {
    @Test func `trending loads and ranks live-shaped analytics by install count`() async {
        let viewModel = makeViewModel(
            formulaAnalytics: Self.liveShapedFormulaAnalytics,
            caskAnalytics: Self.liveShapedCaskAnalytics,
            formulaCatalogueNames: ["a2ps", "wget", "bat"],
            caskCatalogueNames: ["iterm2", "raycast"],
        )

        await viewModel.load()

        guard case .loaded = viewModel.trending else {
            Issue.record("expected trending to load; got \(viewModel.trending)")
            return
        }
        // Ranked by count descending within each kind (formulae then casks), regardless of the
        // alphabetical key order in the payload.
        #expect(viewModel.visiblePackages.map(\.name) == ["wget", "bat", "a2ps", "raycast", "iterm2"])
        #expect(viewModel.selectedPackage?.id == .formula(name: "wget"))
    }

    @Test func `trending surfaces a failure when analytics cannot be decoded`() async {
        let viewModel = makeViewModel(
            formulaAnalytics: Data("not json".utf8),
            caskAnalytics: Data("not json".utf8),
            formulaCatalogueNames: [],
            caskCatalogueNames: [],
        )

        await viewModel.load()

        guard case .failed = viewModel.trending else {
            Issue.record("expected trending to fail on undecodable analytics; got \(viewModel.trending)")
            return
        }
    }

    // MARK: - Fixtures

    /// Mirrors the live `install-on-request` response: name-keyed objects (alphabetical), string counts,
    /// no rank field. Counts intentionally do not follow key order.
    private static let liveShapedFormulaAnalytics = Data(
        """
        {
          "category": "install-on-request",
          "total_items": 3,
          "total_count": 1281,
          "start_date": "2026-04-17",
          "end_date": "2026-05-17",
          "formulae": {
            "a2ps": [{ "formula": "a2ps", "count": "81" }],
            "bat": [{ "formula": "bat", "count": "200" }],
            "wget": [{ "formula": "wget", "count": "1,000" }]
          }
        }
        """.utf8,
    )

    private static let liveShapedCaskAnalytics = Data(
        """
        {
          "category": "cask-install",
          "total_items": 2,
          "total_count": 850,
          "start_date": "2026-04-17",
          "end_date": "2026-05-17",
          "formulae": {
            "iterm2": [{ "cask": "iterm2", "count": "400" }],
            "raycast": [{ "cask": "raycast", "count": "450" }]
          }
        }
        """.utf8,
    )
}

// MARK: - Wiring

private func makeViewModel(
    formulaAnalytics: Data,
    caskAnalytics: Data,
    formulaCatalogueNames: [String],
    caskCatalogueNames: [String],
) -> DiscoverViewModel {
    let catalogueRepository = StubCatalogueRepository(
        formulaCatalogue: formulaCatalogueNames.map { catalogueFormula(named: $0) },
        caskCatalogue: caskCatalogueNames.map { catalogueCask(named: $0) },
    )
    let repository = BrewDiscoverPackagesRepository(
        apiClient: StubAnalyticsAPIClient(formula: formulaAnalytics, cask: caskAnalytics),
        catalogueRepository: catalogueRepository,
        cache: InMemoryDiscoverAnalyticsCache(),
        defaultsKeyPrefix: "DiscoverTrendingIntegration.\(UUID().uuidString)",
    )
    return DiscoverViewModel(
        discoverPackagesRepository: repository,
        catalogueRepository: catalogueRepository,
        installedRepository: StubInstalledPackagesRepository(packages: []),
    )
}

private func catalogueFormula(named name: String) -> BrewPackage {
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

private func catalogueCask(named name: String) -> BrewPackage {
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

/// Returns fixed analytics bytes for both windows; catalogue endpoints are never exercised by the
/// discover repository (enrichment goes through the injected catalogue repository).
private struct StubAnalyticsAPIClient: BrewAPIClient {
    let formula: Data
    let cask: Data

    func fetchFormulaInstallOnRequestAnalytics(
        window _: BrewAnalyticsWindow,
        etag _: String?,
    ) async throws -> CatalogueResponse<Data> {
        .updated(data: formula, etag: nil)
    }

    func fetchCaskInstallAnalytics(
        window _: BrewAnalyticsWindow,
        etag _: String?,
    ) async throws -> CatalogueResponse<Data> {
        .updated(data: cask, etag: nil)
    }

    func fetchFormulaCatalogue(etag _: String?) async throws -> CatalogueResponse<FormulaCatalogueJSON> {
        .notModified
    }

    func fetchCaskCatalogue(etag _: String?) async throws -> CatalogueResponse<CaskCatalogueJSON> {
        .notModified
    }
}
