//
//  CatalogueRepository.swift
//  Brew
//

import Foundation

@MainActor
protocol CatalogueRepository: Sendable {
    func package(for reference: HomebrewPackageReference) async throws -> BrewPackage?
}

@MainActor
enum CatalogueRepositoryError: Error, Equatable {
    case cacheMissingAfterNotModified(kind: CatalogueCache.CatalogueKind)
}

@MainActor
final class BrewCatalogueRepository: CatalogueRepository {
    nonisolated static let defaultTTL: TimeInterval = 3600

    enum DefaultsKey {
        static let formulaLastRefresh = "CatalogueRepository.formula.lastRefresh"
        static let caskLastRefresh = "CatalogueRepository.cask.lastRefresh"
    }

    private let apiClient: any BrewAPIClient
    private let cache: any CatalogueCaching
    private let userDefaults: UserDefaults
    private let now: @Sendable () -> Date
    private let ttl: TimeInterval

    private var refreshTasks: [HomebrewPackageKind: Task<[BrewPackage], Error>] = [:]

    init(
        apiClient: any BrewAPIClient,
        cache: any CatalogueCaching,
        userDefaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = Date.init,
        ttl: TimeInterval = BrewCatalogueRepository.defaultTTL,
    ) {
        self.apiClient = apiClient
        self.cache = cache
        self.userDefaults = userDefaults
        self.now = now
        self.ttl = ttl
    }

    func package(for reference: HomebrewPackageReference) async throws -> BrewPackage? {
        let packages = try await packages(for: reference.kind)
        return packages.first { $0.id == reference.packageID }
    }

    private func packages(for kind: HomebrewPackageKind) async throws -> [BrewPackage] {
        if !isStale(kind: kind.catalogueKind) {
            switch kind {
            case .formula:
                if let catalogue = await cache.formulaCatalogue() {
                    return mapFormulaPackages(from: catalogue)
                }
            case .cask:
                if let catalogue = await cache.caskCatalogue() {
                    return mapCaskPackages(from: catalogue)
                }
            }
        }
        return try await refreshAwaitingSharedTask(for: kind)
    }

    private func refreshAwaitingSharedTask(for kind: HomebrewPackageKind) async throws -> [BrewPackage] {
        if let existing = refreshTasks[kind] {
            return try await existing.value
        }
        let task = Task { try await self.performRefresh(for: kind) }
        refreshTasks[kind] = task
        do {
            let value = try await task.value
            refreshTasks[kind] = nil
            return value
        } catch {
            refreshTasks[kind] = nil
            throw error
        }
    }

    private func performRefresh(for kind: HomebrewPackageKind) async throws -> [BrewPackage] {
        let catalogueKind = kind.catalogueKind
        let etag = await cache.etag(for: catalogueKind)
        switch kind {
        case .formula:
            let response = try await apiClient.fetchFormulaCatalogue(etag: etag)
            switch response {
            case .notModified:
                updateLastRefresh(kind: catalogueKind)
                guard let cached = await cache.formulaCatalogue() else {
                    throw CatalogueRepositoryError.cacheMissingAfterNotModified(kind: .formula)
                }
                return mapFormulaPackages(from: cached)
            case let .updated(data: data, etag: nextETag):
                try await cache.updateFormulaCatalogue(with: JSONEncoder().encode(data.items), etag: nextETag)
                updateLastRefresh(kind: catalogueKind)
                return mapFormulaPackages(from: data)
            }
        case .cask:
            let response = try await apiClient.fetchCaskCatalogue(etag: etag)
            switch response {
            case .notModified:
                updateLastRefresh(kind: catalogueKind)
                guard let cached = await cache.caskCatalogue() else {
                    throw CatalogueRepositoryError.cacheMissingAfterNotModified(kind: .cask)
                }
                return mapCaskPackages(from: cached)
            case let .updated(data: data, etag: nextETag):
                try await cache.updateCaskCatalogue(with: JSONEncoder().encode(data.items), etag: nextETag)
                updateLastRefresh(kind: catalogueKind)
                return mapCaskPackages(from: data)
            }
        }
    }

    private func updateLastRefresh(kind: CatalogueCache.CatalogueKind) {
        userDefaults.set(now(), forKey: lastRefreshKey(for: kind))
    }

    private func isStale(kind: CatalogueCache.CatalogueKind) -> Bool {
        guard let refreshedAt = userDefaults.object(forKey: lastRefreshKey(for: kind)) as? Date else {
            return true
        }
        return now().timeIntervalSince(refreshedAt) >= ttl
    }

    private func lastRefreshKey(for kind: CatalogueCache.CatalogueKind) -> String {
        switch kind {
        case .formula:
            DefaultsKey.formulaLastRefresh
        case .cask:
            DefaultsKey.caskLastRefresh
        }
    }

    private func mapFormulaPackages(from catalogue: FormulaCatalogueJSON) -> [BrewPackage] {
        catalogue.items.map {
            BrewPackage(
                name: $0.name,
                displayName: $0.name,
                kind: .formula,
                description: $0.description,
                homepage: $0.homepage,
                latestVersion: $0.stableVersion,
                dependencies: $0.dependencyReferences,
            )
        }
    }

    private func mapCaskPackages(from catalogue: CaskCatalogueJSON) -> [BrewPackage] {
        catalogue.items.map {
            BrewPackage(
                name: $0.name,
                displayName: $0.displayName,
                kind: .cask,
                description: $0.description ?? "",
                homepage: $0.homepage,
                latestVersion: $0.stableVersion,
                dependencies: $0.dependencyReferences,
            )
        }
    }
}

private extension HomebrewPackageKind {
    var catalogueKind: CatalogueCache.CatalogueKind {
        switch self {
        case .formula: .formula
        case .cask: .cask
        }
    }
}
