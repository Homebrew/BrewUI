//
//  CatalogueRepository.swift
//  Brew
//

import Foundation

@MainActor
protocol CatalogueRepository: Sendable {
    func loadFormulaCatalogue(forceRefresh: Bool) async throws -> FormulaCatalogueJSON
    func loadCaskCatalogue(forceRefresh: Bool) async throws -> CaskCatalogueJSON
}

extension CatalogueRepository {
    func loadFormulaCatalogue() async throws -> FormulaCatalogueJSON {
        try await loadFormulaCatalogue(forceRefresh: false)
    }

    func loadCaskCatalogue() async throws -> CaskCatalogueJSON {
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
    private let cache: CatalogueCache
    private let userDefaults: UserDefaults
    private let now: @Sendable () -> Date
    private let ttl: TimeInterval

    private var formulaRefreshTask: Task<FormulaCatalogueJSON, Error>?
    private var caskRefreshTask: Task<CaskCatalogueJSON, Error>?

    init(
        apiClient: any BrewAPIClient,
        cache: CatalogueCache,
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

    static func live(
        apiClient: any BrewAPIClient = URLSessionBrewAPIClient.live(),
        userDefaults: UserDefaults = .standard,
    ) async -> BrewCatalogueRepository {
        let cache = await CatalogueCache()
        return BrewCatalogueRepository(apiClient: apiClient, cache: cache, userDefaults: userDefaults)
    }

    func loadFormulaCatalogue(forceRefresh: Bool = false) async throws -> FormulaCatalogueJSON {
        if forceRefresh {
            return try await refreshFormulaAwaitingSharedTask()
        }

        if let cached = await cache.formulaCatalogue() {
            if isStale(kind: .formula) {
                scheduleFormulaBackgroundRefreshIfNeeded()
            }
            return cached
        }

        return try await refreshFormulaAwaitingSharedTask()
    }

    func loadCaskCatalogue(forceRefresh: Bool = false) async throws -> CaskCatalogueJSON {
        if forceRefresh {
            return try await refreshCaskAwaitingSharedTask()
        }

        if let cached = await cache.caskCatalogue() {
            if isStale(kind: .cask) {
                scheduleCaskBackgroundRefreshIfNeeded()
            }
            return cached
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

    private func refreshFormulaAwaitingSharedTask() async throws -> FormulaCatalogueJSON {
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

    private func refreshCaskAwaitingSharedTask() async throws -> CaskCatalogueJSON {
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

    private func performFormulaRefresh() async throws -> FormulaCatalogueJSON {
        let etag = await cache.etag(for: .formula)
        let response = try await apiClient.fetchFormulaCatalogue(etag: etag)
        switch response {
        case .notModified:
            updateLastRefresh(kind: .formula)
            if let cached = await cache.formulaCatalogue() {
                return cached
            }
            throw CatalogueRepositoryError.cacheMissingAfterNotModified(kind: .formula)
        case let .updated(data: data, etag: nextETag):
            let rawData = try encodeFormulaPayload(data)
            try await cache.updateFormulaCatalogue(
                with: rawData,
                etag: nextETag,
            )
            updateLastRefresh(kind: .formula)
            return data
        }
    }

    private func performCaskRefresh() async throws -> CaskCatalogueJSON {
        let etag = await cache.etag(for: .cask)
        let response = try await apiClient.fetchCaskCatalogue(etag: etag)
        switch response {
        case .notModified:
            updateLastRefresh(kind: .cask)
            if let cached = await cache.caskCatalogue() {
                return cached
            }
            throw CatalogueRepositoryError.cacheMissingAfterNotModified(kind: .cask)
        case let .updated(data: data, etag: nextETag):
            let rawData = try encodeCaskPayload(data)
            try await cache.updateCaskCatalogue(
                with: rawData,
                etag: nextETag,
            )
            updateLastRefresh(kind: .cask)
            return data
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
}
