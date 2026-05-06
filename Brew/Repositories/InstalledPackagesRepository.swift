//
//  InstalledPackagesRepository.swift
//  Brew
//

import Foundation

/// Loads installed formulae and casks — swap `BrewInstalledPackagesRepository` / test doubles (`CONVENTIONS.md` — Testing).
protocol InstalledPackagesRepository: Sendable {
    func loadInstalledPackages() async throws -> InstalledPackagesSnapshot
    func loadInstalledPackage(kind: InstalledPackageKind, named name: String) async throws -> InstalledPackageInfo
}

extension InstalledPackagesRepository {
    func loadInstalledPackage(kind: InstalledPackageKind, named name: String) async throws -> InstalledPackageInfo {
        let snapshot = try await loadInstalledPackages()
        let package: InstalledPackageInfo? = switch kind {
        case .formula:
            snapshot.formulae.first { $0.name == name }
        case .cask:
            snapshot.casks.first { $0.name == name }
        }
        guard let package else {
            throw InstalledPackagesRepositoryError.packageNotFound(kind: kind, name: name)
        }
        return package
    }
}

enum InstalledPackagesRepositoryError: Error, Equatable {
    case packageNotFound(kind: InstalledPackageKind, name: String)
}
