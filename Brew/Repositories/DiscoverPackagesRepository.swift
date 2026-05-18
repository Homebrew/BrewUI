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
}

extension DiscoverPackagesRepository {
    func loadTopPackages(
        limit: Int = 10,
        window: BrewAnalyticsWindow = .days30,
    ) async throws -> DiscoverTopPackagesSnapshot {
        try await loadTopPackages(limit: limit, window: window)
    }
}

struct BrewDiscoverPackagesRepository: DiscoverPackagesRepository {
    private let apiClient: any BrewAPIClient

    init(apiClient: any BrewAPIClient) {
        self.apiClient = apiClient
    }

    static func live() -> BrewDiscoverPackagesRepository {
        BrewDiscoverPackagesRepository(apiClient: URLSessionBrewAPIClient.live())
    }

    func loadTopPackages(
        limit: Int = 10,
        window: BrewAnalyticsWindow = .days30,
    ) async throws -> DiscoverTopPackagesSnapshot {
        async let formulaAnalytics = apiClient.fetchFormulaInstallOnRequestAnalytics(window: window)
        async let caskAnalytics = apiClient.fetchCaskInstallAnalytics(window: window)

        let formulae = try await topPackages(from: formulaAnalytics, limit: limit)
        let casks = try await topPackages(from: caskAnalytics, limit: limit)
        return DiscoverTopPackagesSnapshot(topFormulae: formulae, topCasks: casks)
    }

    private func topPackages(from analytics: BrewAnalyticsJSON, limit: Int) -> [DiscoverTopPackage] {
        let validatedLimit = max(0, limit)
        guard validatedLimit > 0 else {
            return []
        }

        return analytics.packageCounts
            .sorted(by: sortByInstallCountDescendingThenNameAscending)
            .prefix(validatedLimit)
            .map { DiscoverTopPackage(reference: $0.reference, installCount: $0.count) }
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
