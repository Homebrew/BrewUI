//
//  InstalledPackagesRepository.swift
//  Brew
//

import Foundation

/// Loads installed formulae and casks — swap `BrewInstalledPackagesRepository` / test doubles (`CONVENTIONS.md` — Testing).
protocol InstalledPackagesRepository: Sendable {
    func loadInstalledPackages() async throws -> InstalledPackagesSnapshot
}
