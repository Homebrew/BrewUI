//
//  CatalogueRepository.swift
//  Brew
//

import Foundation

@MainActor
protocol CatalogueRepository: Sendable {
    func package(for reference: HomebrewPackageID) async throws -> BrewPackage?
    /// Catalogue-wide name search across both formulae and casks, capped at `limit` results.
    func searchPackages(matching query: String, limit: Int) async throws -> [BrewPackage]
}

@MainActor
enum CatalogueRepositoryError: Error, Equatable {
    case cacheMissingAfterNotModified(kind: CatalogueCache.CatalogueKind)
}

@MainActor
final class BrewCatalogueRepository: CatalogueRepository {
    nonisolated static let defaultTTL: TimeInterval = 3600

    private let apiClient: any BrewAPIClient
    private let cache: any CatalogueCaching
    private let defaultsKeyPrefix: String
    private let now: @Sendable () -> Date
    private let ttl: TimeInterval

    private var refreshTasks: [HomebrewPackageKind: Task<[BrewPackage], Error>] = [:]

    /// `defaultsKeyPrefix` is the test seam for `UserDefaults.standard`; tests pass a unique prefix
    /// to isolate their lastRefresh timestamps from each other and from production data.
    init(
        apiClient: any BrewAPIClient,
        cache: any CatalogueCaching,
        defaultsKeyPrefix: String = "CatalogueRepository",
        now: @escaping @Sendable () -> Date = Date.init,
        ttl: TimeInterval = BrewCatalogueRepository.defaultTTL,
    ) {
        self.apiClient = apiClient
        self.cache = cache
        self.defaultsKeyPrefix = defaultsKeyPrefix
        self.now = now
        self.ttl = ttl
    }

    func lastRefreshKey(for kind: CatalogueCache.CatalogueKind) -> String {
        "\(defaultsKeyPrefix).\(kind.rawValue).lastRefresh"
    }

    func package(for reference: HomebrewPackageID) async throws -> BrewPackage? {
        let packages = try await packages(for: reference.kind)
        return packages.first { $0.id == reference }
    }

    func searchPackages(matching query: String, limit: Int) async throws -> [BrewPackage] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, limit > 0 else {
            return []
        }

        async let formulaeTask = packages(for: .formula)
        async let casksTask = packages(for: .cask)
        let formulae = try await formulaeTask
        let casks = try await casksTask

        let loweredQuery = trimmedQuery.lowercased()
        let matches = (formulae + casks).filter { package in
            package.name.localizedCaseInsensitiveContains(trimmedQuery)
                || package.displayName.localizedCaseInsensitiveContains(trimmedQuery)
        }
        // Surface prefix matches first, then fall back to alphabetical so the most likely target leads.
        let ranked = matches.sorted { lhs, rhs in
            let lhsLeads = lhs.name.lowercased().hasPrefix(loweredQuery)
            let rhsLeads = rhs.name.lowercased().hasPrefix(loweredQuery)
            if lhsLeads != rhsLeads {
                return lhsLeads
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return Array(ranked.prefix(limit))
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
        UserDefaults.standard.set(now(), forKey: lastRefreshKey(for: kind))
    }

    private func isStale(kind: CatalogueCache.CatalogueKind) -> Bool {
        guard let refreshedAt = UserDefaults.standard.object(forKey: lastRefreshKey(for: kind)) as? Date else {
            return true
        }
        return now().timeIntervalSince(refreshedAt) >= ttl
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
