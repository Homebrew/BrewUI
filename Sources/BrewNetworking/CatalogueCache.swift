//
//  CatalogueCache.swift
//  Brew
//

import Foundation

public actor CatalogueCache: CatalogueCaching {
    public enum CatalogueKind: String, Sendable {
        case formula
        case cask
    }

    private let cacheDirectoryURL: URL
    private let defaultsKeyPrefix: String
    private let decoder = JSONDecoder()

    private var formulaData: FormulaCatalogueJSON?
    private var caskData: CaskCatalogueJSON?
    private var hasPrepared = false
    private var prepareTask: Task<(FormulaCatalogueJSON?, CaskCatalogueJSON?), Never>?

    /// `cacheDirectoryURL` and `defaultsKeyPrefix` are the only test seams; the actor reaches for
    /// `FileManager.default` / `UserDefaults.standard` itself so it doesn't have to store
    /// non-Sendable singletons. Tests pass a unique tmp directory + unique key prefix to isolate.
    public init(
        cacheDirectoryURL: URL? = nil,
        defaultsKeyPrefix: String = "CatalogueCache",
    ) {
        self.cacheDirectoryURL = cacheDirectoryURL ?? Self.defaultCacheDirectoryURL()
        self.defaultsKeyPrefix = defaultsKeyPrefix
    }

    public func prepare() async {
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

    public func formulaCatalogue() async -> FormulaCatalogueJSON? {
        formulaData
    }

    public func caskCatalogue() async -> CaskCatalogueJSON? {
        caskData
    }

    public func etag(for kind: CatalogueKind) async -> String? {
        UserDefaults.standard.string(forKey: etagKey(for: kind))
    }

    public func updateFormulaCatalogue(with rawData: Data, etag: String?) async throws {
        let decoded = try decoder.decode(FormulaCatalogueJSON.self, from: rawData)
        try writeCache(rawData, to: formulaCacheFileURL)
        formulaData = decoded
        persistETag(etag, for: .formula)
    }

    public func updateCaskCatalogue(with rawData: Data, etag: String?) async throws {
        let decoded = try decoder.decode(CaskCatalogueJSON.self, from: rawData)
        try writeCache(rawData, to: caskCacheFileURL)
        caskData = decoded
        persistETag(etag, for: .cask)
    }

    private func writeCache(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func persistETag(_ etag: String?, for kind: CatalogueKind) {
        let key = etagKey(for: kind)
        if let etag {
            UserDefaults.standard.set(etag, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func etagKey(for kind: CatalogueKind) -> String {
        "\(defaultsKeyPrefix).\(kind.rawValue).etag"
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
    nonisolated static func defaultCacheDirectoryURL() -> URL {
        let fileManager = FileManager.default
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
