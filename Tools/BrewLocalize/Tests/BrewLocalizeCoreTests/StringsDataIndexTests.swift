@testable import BrewLocalizeCore
import Foundation
import Testing

@Suite("StringsDataIndex")
struct StringsDataIndexTests {
    private func makeIndex(entries: [(name: String, source: String)]) throws -> (TemporaryRepo, StringsDataIndex) {
        var files: [String: String] = [:]
        for entry in entries {
            files["stringsdata/\(entry.name).stringsdata"] = #"{ "source": "\#(entry.source)", "tables": {}, "version": 1 }"#
        }
        let repo = try TemporaryRepo.make(files: files)
        return (repo, StringsDataIndex(directories: [repo.url.appendingPathComponent("stringsdata")]))
    }

    @Test
    func `files are found by the source path recorded inside them`() throws {
        let (repo, index) = try makeIndex(entries: [("A", "/src/A.swift"), ("B", "/src/B.swift")])
        defer { repo.remove() }
        let files = try index.files(for: ["/src/B.swift"])
        #expect(files.map(\.lastPathComponent) == ["B.stringsdata"])
    }

    @Test
    func `every missing source is named in the failure`() throws {
        let (repo, index) = try makeIndex(entries: [("A", "/src/A.swift")])
        defer { repo.remove() }
        #expect(throws: StringsDataIndex.Failure.missing(sources: ["/src/B.swift", "/src/C.swift"])) {
            try index.files(for: ["/src/A.swift", "/src/B.swift", "/src/C.swift"])
        }
    }

    @Test
    func `files that are not string data are ignored`() throws {
        let repo = try TemporaryRepo.make(files: ["stringsdata/notes.txt": "x", "stringsdata/bad.stringsdata": "{"])
        defer { repo.remove() }
        let index = StringsDataIndex(directories: [repo.url.appendingPathComponent("stringsdata")])
        #expect(throws: StringsDataIndex.Failure.self) { try index.files(for: ["/src/A.swift"]) }
    }
}
