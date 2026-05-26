//
//  CatalogueCacheTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct CatalogueCacheTests {
    @Test @MainActor func `prepare loads formula and cask cache from disk`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }

        let formulaRawData = fixture.formulaCacheJSON(name: "wget")
        let caskRawData = fixture.caskCacheJSON(name: "iterm2")
        try fixture.writeFormulaCache(formulaRawData)
        try fixture.writeCaskCache(caskRawData)
        UserDefaults.standard.set(#""formula-etag""#, forKey: fixture.formulaETagKey)
        UserDefaults.standard.set(#""cask-etag""#, forKey: fixture.caskETagKey)

        let cache = CatalogueCache(
            cacheDirectoryURL: fixture.cacheDirectoryURL,
            defaultsKeyPrefix: fixture.defaultsKeyPrefix,
        )
        await cache.prepare()

        #expect(await cache.formulaCatalogue()?.items.first?.name == "wget")
        #expect(await cache.caskCatalogue()?.items.first?.name == "iterm2")
        #expect(await cache.etag(for: .formula) == #""formula-etag""#)
        #expect(await cache.etag(for: .cask) == #""cask-etag""#)
    }

    @Test @MainActor func `first read returns prepared cache`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }
        let formulaRawData = fixture.formulaCacheJSON(name: "curl")
        try fixture.writeFormulaCache(formulaRawData)

        let cache = CatalogueCache(
            cacheDirectoryURL: fixture.cacheDirectoryURL,
            defaultsKeyPrefix: fixture.defaultsKeyPrefix,
        )
        await cache.prepare()

        #expect(await cache.formulaCatalogue()?.items.first?.name == "curl")
    }

    @Test @MainActor func `update formula cache persists raw body and etag`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }
        let cache = CatalogueCache(
            cacheDirectoryURL: fixture.cacheDirectoryURL,
            defaultsKeyPrefix: fixture.defaultsKeyPrefix,
        )
        let updatedRawData = fixture.formulaCacheJSON(name: "git")

        try await cache.updateFormulaCatalogue(with: updatedRawData, etag: #""formula-new""#)

        #expect(await cache.formulaCatalogue()?.items.first?.name == "git")
        #expect(await cache.etag(for: .formula) == #""formula-new""#)

        let persistedRawData = try Data(contentsOf: fixture.formulaCacheURL)
        #expect(persistedRawData == updatedRawData)
    }

    @Test @MainActor func `prepare does not overwrite in memory updates`() async throws {
        let fixture = TestFixture()
        defer { fixture.cleanup() }

        try fixture.writeFormulaCache(fixture.formulaCacheJSON(name: "stale"))
        let cache = CatalogueCache(
            cacheDirectoryURL: fixture.cacheDirectoryURL,
            defaultsKeyPrefix: fixture.defaultsKeyPrefix,
        )
        let updatedRawData = fixture.formulaCacheJSON(name: "fresh")
        try await cache.updateFormulaCatalogue(with: updatedRawData, etag: #""formula-fresh""#)

        await cache.prepare()

        #expect(await cache.formulaCatalogue()?.items.first?.name == "fresh")
        #expect(await cache.etag(for: .formula) == #""formula-fresh""#)
    }
}

private struct TestFixture {
    let cacheDirectoryURL: URL
    let formulaCacheURL: URL
    let caskCacheURL: URL
    let defaultsKeyPrefix: String

    var formulaETagKey: String {
        "\(defaultsKeyPrefix).formula.etag"
    }

    var caskETagKey: String {
        "\(defaultsKeyPrefix).cask.etag"
    }

    init() {
        let id = UUID().uuidString
        cacheDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CatalogueCacheTests-\(id)", isDirectory: true)
        formulaCacheURL = cacheDirectoryURL.appendingPathComponent("formula-cache.json")
        caskCacheURL = cacheDirectoryURL.appendingPathComponent("cask-cache.json")
        defaultsKeyPrefix = "CatalogueCacheTests.\(id)"
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: cacheDirectoryURL)
        UserDefaults.standard.removePersistedKeys(withPrefix: defaultsKeyPrefix)
    }

    func writeFormulaCache(_ data: Data) throws {
        try FileManager.default.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        try data.write(to: formulaCacheURL, options: .atomic)
    }

    func writeCaskCache(_ data: Data) throws {
        try FileManager.default.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        try data.write(to: caskCacheURL, options: .atomic)
    }

    func formulaCacheJSON(name: String) -> Data {
        Data(
            """
            [
              {
                "name": "\(name)",
                "desc": "Formula \(name)",
                "homepage": "https://example.com/\(name)",
                "versions": { "stable": "1.0.0" },
                "dependencies": []
              }
            ]
            """.utf8,
        )
    }

    func caskCacheJSON(name: String) -> Data {
        Data(
            """
            [
              {
                "token": "\(name)",
                "name": ["\(name)"],
                "desc": "Cask \(name)",
                "homepage": "https://example.com/\(name)",
                "version": "2.0.0",
                "depends_on": { "macos": {} }
              }
            ]
            """.utf8,
        )
    }
}
