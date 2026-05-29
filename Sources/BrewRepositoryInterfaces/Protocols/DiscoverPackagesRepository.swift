//
//  DiscoverPackagesRepository.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

public protocol DiscoverPackagesRepository: Sendable {
    func loadTopPackages(
        limit: Int,
        window: BrewAnalyticsWindow,
    ) async throws -> DiscoverTopPackagesSnapshot
}

public extension DiscoverPackagesRepository {
    func loadTopPackages(
        limit: Int = 10,
        window: BrewAnalyticsWindow = .days30,
    ) async throws -> DiscoverTopPackagesSnapshot {
        try await loadTopPackages(limit: limit, window: window)
    }
}
