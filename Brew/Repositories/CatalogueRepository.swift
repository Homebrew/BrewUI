//
//  CatalogueRepository.swift
//  Brew
//

import Foundation

@MainActor
protocol CatalogueRepository: Sendable {
    func loadFormulaCatalogue(forceRefresh: Bool) async throws -> [BrewPackage]
    func loadCaskCatalogue(forceRefresh: Bool) async throws -> [BrewPackage]
}

extension CatalogueRepository {
    func loadFormulaCatalogue() async throws -> [BrewPackage] {
        try await loadFormulaCatalogue(forceRefresh: false)
    }

    func loadCaskCatalogue() async throws -> [BrewPackage] {
        try await loadCaskCatalogue(forceRefresh: false)
    }
}

@MainActor
enum CatalogueRepositoryError: Error, Equatable {
    case cacheMissingAfterNotModified(kind: CatalogueCache.CatalogueKind)
}

@MainActor
final class BrewCatalogueRepository: CatalogueRepository {
    nonisolated static let defaultTTL: TimeInterval = 3600

    private enum DefaultsKey {
        static let formulaLastRefresh = "CatalogueRepository.formula.lastRefresh"
        static let caskLastRefresh = "CatalogueRepository.cask.lastRefresh"
    }

    private let apiClient: any BrewAPIClient
    private let cache: any CatalogueCaching
    private let userDefaults: UserDefaults
    private let now: @Sendable () -> Date
    private let ttl: TimeInterval

    private var formulaRefreshTask: Task<[BrewPackage], Error>?
    private var caskRefreshTask: Task<[BrewPackage], Error>?

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

    func loadFormulaCatalogue(forceRefresh: Bool = false) async throws -> [BrewPackage] {
        if forceRefresh {
            return try await refreshFormulaAwaitingSharedTask()
        }

        if let cached = await cache.formulaCatalogue() {
            if isStale(kind: .formula) {
                scheduleFormulaBackgroundRefreshIfNeeded()
            }
            return mapFormulaPackages(from: cached)
        }

        return try await refreshFormulaAwaitingSharedTask()
    }

    func loadCaskCatalogue(forceRefresh: Bool = false) async throws -> [BrewPackage] {
        if forceRefresh {
            return try await refreshCaskAwaitingSharedTask()
        }

        if let cached = await cache.caskCatalogue() {
            if isStale(kind: .cask) {
                scheduleCaskBackgroundRefreshIfNeeded()
            }
            return mapCaskPackages(from: cached)
        }

        return try await refreshCaskAwaitingSharedTask()
    }

    private func scheduleFormulaBackgroundRefreshIfNeeded() {
        guard formulaRefreshTask == nil else { return }
        Task { @MainActor [self] in
            _ = try? await refreshFormulaAwaitingSharedTask()
        }
    }

    private func scheduleCaskBackgroundRefreshIfNeeded() {
        guard caskRefreshTask == nil else { return }
        Task { @MainActor [self] in
            _ = try? await refreshCaskAwaitingSharedTask()
        }
    }

    private func refreshFormulaAwaitingSharedTask() async throws -> [BrewPackage] {
        if let existingTask = formulaRefreshTask {
            return try await existingTask.value
        }

        let task = Task { try await performFormulaRefresh() }
        formulaRefreshTask = task
        do {
            let value = try await task.value
            formulaRefreshTask = nil
            return value
        } catch {
            formulaRefreshTask = nil
            throw error
        }
    }

    private func refreshCaskAwaitingSharedTask() async throws -> [BrewPackage] {
        if let existingTask = caskRefreshTask {
            return try await existingTask.value
        }

        let task = Task { try await performCaskRefresh() }
        caskRefreshTask = task
        do {
            let value = try await task.value
            caskRefreshTask = nil
            return value
        } catch {
            caskRefreshTask = nil
            throw error
        }
    }

    private func performFormulaRefresh() async throws -> [BrewPackage] {
        let etag = await cache.etag(for: .formula)
        let response = try await apiClient.fetchFormulaCatalogue(etag: etag)
        switch response {
        case .notModified:
            updateLastRefresh(kind: .formula)
            if let cached = await cache.formulaCatalogue() {
                return mapFormulaPackages(from: cached)
            }
            throw CatalogueRepositoryError.cacheMissingAfterNotModified(kind: .formula)
        case let .updated(data: data, etag: nextETag):
            let rawData = try encodeFormulaPayload(data)
            try await cache.updateFormulaCatalogue(
                with: rawData,
                etag: nextETag,
            )
            updateLastRefresh(kind: .formula)
            return mapFormulaPackages(from: data)
        }
    }

    private func performCaskRefresh() async throws -> [BrewPackage] {
        let etag = await cache.etag(for: .cask)
        let response = try await apiClient.fetchCaskCatalogue(etag: etag)
        switch response {
        case .notModified:
            updateLastRefresh(kind: .cask)
            if let cached = await cache.caskCatalogue() {
                return mapCaskPackages(from: cached)
            }
            throw CatalogueRepositoryError.cacheMissingAfterNotModified(kind: .cask)
        case let .updated(data: data, etag: nextETag):
            let rawData = try encodeCaskPayload(data)
            try await cache.updateCaskCatalogue(
                with: rawData,
                etag: nextETag,
            )
            updateLastRefresh(kind: .cask)
            return mapCaskPackages(from: data)
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

    private func encodeFormulaPayload(_ catalogue: FormulaCatalogueJSON) throws -> Data {
        try JSONEncoder().encode(catalogue.items)
    }

    private func encodeCaskPayload(_ catalogue: CaskCatalogueJSON) throws -> Data {
        try JSONEncoder().encode(catalogue.items)
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
                displayName: $0.name,
                kind: .cask,
                description: $0.description,
                homepage: $0.homepage,
                latestVersion: $0.stableVersion,
                dependencies: $0.dependencyReferences,
            )
        }
    }
}
