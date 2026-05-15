//
//  InstalledPackagesRepository.swift
//  Brew
//

import Foundation

/// Loads installed formulae and casks — swap `BrewInstalledPackagesRepository` / test doubles (`CONVENTIONS.md` — Testing).
@MainActor
protocol InstalledPackagesRepository: Sendable {
    func loadInstalledPackages(forceRefresh: Bool) async throws -> [BrewPackage]
}

extension InstalledPackagesRepository {
    func loadInstalledPackages() async throws -> [BrewPackage] {
        try await loadInstalledPackages(forceRefresh: false)
    }
}
