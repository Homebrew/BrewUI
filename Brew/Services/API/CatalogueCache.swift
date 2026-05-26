//
//  CatalogueCache.swift
//  Brew
//

import Foundation

actor CatalogueCache: CatalogueCaching {
    enum CatalogueKind: String {
        case formula
        case cask
    }

    private enum DefaultsKey {
        static let formulaETag = "CatalogueCache.formula.etag"
        static let caskETag = "CatalogueCache.cask.etag"
    }

    // `FileManager` and `UserDefaults` are documented thread-safe but not Sendable, so the only way to
    // hold injected instances inside an actor whose init runs on MainActor (per file-default isolation)
    // is `nonisolated(unsafe)` — same escape hatch Apple uses for Foundation singletons in URLSession.
    private nonisolated(unsafe) let fileManager: FileManager
    private nonisolated(unsafe) let userDefaults: UserDefaults
    private let cacheDirectoryURL: URL
    private let decoder = JSONDecoder()

    private var formulaData: FormulaCatalogueJSON?
    private var caskData: CaskCatalogueJSON?
    private var hasPrepared = false
    private var prepareTask: Task<(FormulaCatalogueJSON?, CaskCatalogueJSON?), Never>?

    init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        cacheDirectoryURL: URL? = nil,
    ) {
        let resolvedURL = cacheDirectoryURL ?? Self.defaultCacheDirectoryURL(fileManager: fileManager)
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        self.cacheDirectoryURL = resolvedURL
    }

    func prepare() async {
        if hasPrepared {
            return
        }

        if let inFlightTask = prepareTask {
            let (loadedFormula, loadedCask) = await inFlightTask.value
            applyPreparedData(formula: loadedFormula, cask: loadedCask)
            hasPrepared = true
            return
        }

        let formulaCacheURL = Self.formulaCacheURL(in: cacheDirectoryURL)
        let caskCacheURL = Self.caskCacheURL(in: cacheDirectoryURL)

        let task = Task(priority: .utility) {
            async let formula = Self.loadCache(at: formulaCacheURL, as: FormulaCatalogueJSON.self)
            async let cask = Self.loadCache(at: caskCacheURL, as: CaskCatalogueJSON.self)
            return await (formula, cask)
        }
        prepareTask = task
        let (loadedFormula, loadedCask) = await task.value
        prepareTask = nil
        applyPreparedData(formula: loadedFormula, cask: loadedCask)
        hasPrepared = true
    }

    func formulaCatalogue() async -> FormulaCatalogueJSON? {
        formulaData
    }

    func caskCatalogue() async -> CaskCatalogueJSON? {
        caskData
    }

    func etag(for kind: CatalogueKind) async -> String? {
        userDefaults.string(forKey: etagKey(for: kind))
    }

    func updateFormulaCatalogue(with rawData: Data, etag: String?) async throws {
        let decoded = try decoder.decode(FormulaCatalogueJSON.self, from: rawData)
        try writeCache(rawData, to: formulaCacheFileURL)
        formulaData = decoded
        persistETag(etag, for: .formula)
    }

    func updateCaskCatalogue(with rawData: Data, etag: String?) async throws {
        let decoded = try decoder.decode(CaskCatalogueJSON.self, from: rawData)
        try writeCache(rawData, to: caskCacheFileURL)
        caskData = decoded
        persistETag(etag, for: .cask)
    }

    private func writeCache(_ data: Data, to url: URL) throws {
        try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func persistETag(_ etag: String?, for kind: CatalogueKind) {
        let key = etagKey(for: kind)
        if let etag {
            userDefaults.set(etag, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    private func etagKey(for kind: CatalogueKind) -> String {
        switch kind {
        case .formula:
            DefaultsKey.formulaETag
        case .cask:
            DefaultsKey.caskETag
        }
    }

    private var formulaCacheFileURL: URL {
        Self.formulaCacheURL(in: cacheDirectoryURL)
    }

    private var caskCacheFileURL: URL {
        Self.caskCacheURL(in: cacheDirectoryURL)
    }

    private func applyPreparedData(formula: FormulaCatalogueJSON?, cask: CaskCatalogueJSON?) {
        if formulaData == nil, let formula {
            formulaData = formula
        }
        if caskData == nil, let cask {
            caskData = cask
        }
    }
}

private extension CatalogueCache {
    nonisolated static func defaultCacheDirectoryURL(fileManager: FileManager) -> URL {
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupportURL.appendingPathComponent("Brew", isDirectory: true)
        }
        return fileManager.temporaryDirectory.appendingPathComponent("Brew", isDirectory: true)
    }

    nonisolated static func formulaCacheURL(in directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent("formula-cache.json")
    }

    nonisolated static func caskCacheURL(in directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent("cask-cache.json")
    }

    nonisolated static func loadCache<T: Decodable>(at url: URL, as type: T.Type) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
