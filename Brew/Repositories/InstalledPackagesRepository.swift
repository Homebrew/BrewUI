//
//  InstalledPackagesRepository.swift
//  Brew
//

import Foundation

/// Loads installed formulae and casks — swap `BrewInstalledPackagesRepository` / test doubles (`CONVENTIONS.md` — Testing).
@MainActor
protocol InstalledPackagesRepository: Sendable {
    func loadInstalledPackages(forceRefresh: Bool) async throws -> [InstalledBrewPackage]
}

extension InstalledPackagesRepository {
    func loadInstalledPackages() async throws -> [InstalledBrewPackage] {
        try await loadInstalledPackages(forceRefresh: false)
    }
}
