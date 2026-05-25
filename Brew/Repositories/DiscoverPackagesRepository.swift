//
//  DiscoverPackagesRepository.swift
//  Brew
//

import Foundation

@MainActor
protocol DiscoverPackagesRepository: Sendable {
    func loadTopPackages(
        limit: Int,
        window: BrewAnalyticsWindow,
    ) async throws -> DiscoverTopPackagesSnapshot

    /// Catalogue search for the Discover tab. Results carry no analytics, so install counts are zero.
    func search(
        query: String,
        limit: Int,
    ) async throws -> [DiscoveryBrewPackage]
}

extension DiscoverPackagesRepository {
    func loadTopPackages(
        limit: Int = 10,
        window: BrewAnalyticsWindow = .days30,
    ) async throws -> DiscoverTopPackagesSnapshot {
        try await loadTopPackages(limit: limit, window: window)
    }

    func search(
        query: String,
        limit: Int = 50,
    ) async throws -> [DiscoveryBrewPackage] {
        try await search(query: query, limit: limit)
    }
}

struct BrewDiscoverPackagesRepository: DiscoverPackagesRepository {
    private let apiClient: any BrewAPIClient
    private let catalogueRepository: any CatalogueRepository

    init(
        apiClient: any BrewAPIClient,
        catalogueRepository: any CatalogueRepository,
    ) {
        self.apiClient = apiClient
        self.catalogueRepository = catalogueRepository
    }

    func loadTopPackages(
        limit: Int = 10,
        window: BrewAnalyticsWindow = .days30,
    ) async throws -> DiscoverTopPackagesSnapshot {
        async let formulaAnalyticsTask = apiClient.fetchFormulaInstallOnRequestAnalytics(window: window)
        async let caskAnalyticsTask = apiClient.fetchCaskInstallAnalytics(window: window)
        let formulaAnalytics = try await formulaAnalyticsTask
        let caskAnalytics = try await caskAnalyticsTask

        async let formulae = topPackages(
            from: formulaAnalytics,
            catalogueRepository: catalogueRepository,
            limit: limit,
        )
        async let casks = topPackages(
            from: caskAnalytics,
            catalogueRepository: catalogueRepository,
            limit: limit,
        )

        return try await DiscoverTopPackagesSnapshot(
            topFormulae: formulae,
            topCasks: casks,
        )
    }

    func search(
        query: String,
        limit: Int = 50,
    ) async throws -> [DiscoveryBrewPackage] {
        let matches = try await catalogueRepository.searchPackages(matching: query, limit: limit)
        return matches.map { DiscoveryBrewPackage(package: $0, thirtyDayInstallCount: 0) }
    }

    private func topPackages(
        from analytics: BrewAnalyticsJSON,
        catalogueRepository: any CatalogueRepository,
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
}
