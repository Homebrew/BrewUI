//
//  CatalogueJSONTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewNetworking
import Foundation
import Testing

struct CatalogueJSONTests {
    @Test func `decodes homebrew wire formula bulk shape`() throws {
        let data = Data(
            """
            [
              {
                "name": "a2ps",
                "desc": "Any-to-PostScript filter",
                "homepage": "https://www.gnu.org/software/a2ps/",
                "versions": { "stable": "4.15.8" },
                "dependencies": ["bdw-gc", "libpaper"]
              }
            ]
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(FormulaCatalogueJSON.self, from: data)

        #expect(decoded.items.count == 1)
        #expect(decoded.decodeFailures.isEmpty)
        #expect(decoded.items.first?.name == "a2ps")
        #expect(decoded.items.first?.description == "Any-to-PostScript filter")
        #expect(decoded.items.first?.stableVersion == "4.15.8")
        #expect(decoded.items.first?.dependencyReferences == [.formula(name: "bdw-gc"), .formula(name: "libpaper")])
    }

    @Test func `formula stable version carries the packaging revision`() throws {
        let data = Data(
            """
            [
              {
                "name": "ffmpeg",
                "desc": "Play, record, convert, and stream audio and video",
                "homepage": "https://ffmpeg.org/",
                "versions": { "stable": "9.0.1" },
                "revision": 1,
                "dependencies": []
              },
              {
                "name": "wget",
                "desc": "Network downloader",
                "homepage": "https://www.gnu.org/software/wget/",
                "versions": { "stable": "1.25.0" },
                "revision": 0,
                "dependencies": []
              }
            ]
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(FormulaCatalogueJSON.self, from: data)

        #expect(decoded.decodeFailures.isEmpty)
        #expect(decoded.items.first(where: { $0.name == "ffmpeg" })?.stableVersion == "9.0.1_1")
        #expect(decoded.items.first(where: { $0.name == "wget" })?.stableVersion == "1.25.0")
    }

    @Test func `formula item without a revision field still decodes`() throws {
        let data = Data(
            """
            [
              {
                "name": "a2ps",
                "desc": "Any-to-PostScript filter",
                "homepage": "https://www.gnu.org/software/a2ps/",
                "versions": { "stable": "4.15.8" },
                "dependencies": []
              }
            ]
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(FormulaCatalogueJSON.self, from: data)

        #expect(decoded.decodeFailures.isEmpty)
        #expect(decoded.items.first?.stableVersion == "4.15.8")
    }

    @Test func `decodes homebrew wire cask bulk shape`() throws {
        let data = Data(
            """
            [
              {
                "token": "0-ad",
                "name": ["0 A.D."],
                "desc": "Real-time strategy game",
                "homepage": "https://play0ad.com/",
                "version": "0.28.0",
                "depends_on": { "macos": {} }
              }
            ]
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(CaskCatalogueJSON.self, from: data)

        #expect(decoded.items.count == 1)
        #expect(decoded.decodeFailures.isEmpty)
        #expect(decoded.items.first?.name == "0-ad")
        #expect(decoded.items.first?.displayName == "0 A.D.")
        #expect(decoded.items.first?.stableVersion == "0.28.0")
    }

    @Test func `decodes cask depends on formula and cask arrays`() throws {
        let data = Data(
            """
            [
              {
                "token": "docker-desktop",
                "name": ["Docker Desktop"],
                "desc": "Docker Desktop",
                "homepage": "https://example.com/docker-desktop",
                "version": "4.0.0",
                "depends_on": {
                  "formula": ["colima", "docker"],
                  "cask": ["iterm2"]
                }
              }
            ]
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(CaskCatalogueJSON.self, from: data)

        #expect(decoded.items.count == 1)
        #expect(decoded.decodeFailures.isEmpty)
        #expect(
            decoded.items.first?.dependencyReferences == [
                .formula(name: "colima"),
                .formula(name: "docker"),
                .cask(token: "iterm2"),
            ],
        )
    }

    @Test func `decodes cask with null desc`() throws {
        let data = Data(
            """
            [
              {
                "token": "0-ad",
                "name": ["0 A.D."],
                "desc": null,
                "homepage": "https://play0ad.com/",
                "version": "0.28.0",
                "depends_on": { "macos": {} }
              }
            ]
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(CaskCatalogueJSON.self, from: data)

        #expect(decoded.items.count == 1)
        #expect(decoded.decodeFailures.isEmpty)
        #expect(decoded.items.first?.description == nil)
    }

    @Test func `decodes cask with omitted desc`() throws {
        let data = Data(
            """
            [
              {
                "token": "0-ad",
                "name": ["0 A.D."],
                "homepage": "https://play0ad.com/",
                "version": "0.28.0",
                "depends_on": { "macos": {} }
              }
            ]
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(CaskCatalogueJSON.self, from: data)

        #expect(decoded.items.count == 1)
        #expect(decoded.decodeFailures.isEmpty)
        #expect(decoded.items.first?.description == nil)
    }

    @Test func `legacy cask catalogue shape fails decode`() throws {
        let data = Data(
            """
            [
              {
                "name": "iterm2",
                "desc": "Terminal emulator",
                "homepage": "https://iterm2.com",
                "versions": { "stable": "3.5.0" }
              }
            ]
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(CaskCatalogueJSON.self, from: data)

        #expect(decoded.items.isEmpty)
        #expect(decoded.decodeFailures.count == 1)
        #expect(decoded.decodeFailures.first?.index == 0)
    }

    @Test func `collects per item decode failures without dropping valid formula items`() throws {
        let data = Data(
            """
            [
              {
                "name": "wget",
                "desc": "Network downloader",
                "homepage": "https://www.gnu.org/software/wget/",
                "versions": { "stable": "1.24.5" },
                "dependencies": []
              },
              {
                "name": "broken-item"
              }
            ]
            """.utf8,
        )

        let decoded = try JSONDecoder().decode(FormulaCatalogueJSON.self, from: data)

        #expect(decoded.items.count == 1)
        #expect(decoded.items.first?.name == "wget")
        #expect(decoded.decodeFailures.count == 1)
        #expect(decoded.decodeFailures.first?.index == 1)
    }
}
