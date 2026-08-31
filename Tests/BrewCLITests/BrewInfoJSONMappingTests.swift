//
//  BrewInfoJSONMappingTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import Foundation
import Testing

struct BrewInfoJSONMappingTests {
    @Test func `installedPackages interleaves formulae and casks name-sorted across both kinds`() throws {
        // Both arrays arrive out of order, and the sorted result must weave the two kinds together:
        // alfred (cask) < git (formula) < ripgrep (formula) < slack (cask).
        let json = """
        {
          "formulae": [
            { "name": "ripgrep" },
            { "name": "git" }
          ],
          "casks": [
            { "token": "slack" },
            { "token": "alfred" }
          ]
        }
        """

        let payload = try JSONDecoder().decode(BrewInfoJSON.self, from: Data(json.utf8))
        let packages = payload.installedPackages()

        #expect(packages.map(\.name) == ["alfred", "git", "ripgrep", "slack"])
        // Casks and formulae are genuinely interleaved, not grouped by kind.
        #expect(packages.map(\.kind) == [.cask, .formula, .formula, .cask])
    }

    @Test func `formula upgrade target keeps the packaging revision suffix`() throws {
        // A revision bump leaves versions.stable alone, so without the revision the upgrade target
        // reads back as the installed keg ("9.0.1 → 9.0.1").
        let json = """
        {
          "formulae": [
            {
              "name": "ffmpeg",
              "versions": { "stable": "9.0.1" },
              "revision": 1,
              "installed": [{ "version": "9.0.1" }],
              "outdated": true
            },
            {
              "name": "wget",
              "versions": { "stable": "1.25.0" },
              "revision": 0,
              "installed": [{ "version": "1.25.0" }]
            },
            {
              "name": "aria2",
              "versions": { "stable": "1.37.0" },
              "installed": [{ "version": "1.37.0" }]
            }
          ],
          "casks": []
        }
        """

        let payload = try JSONDecoder().decode(BrewInfoJSON.self, from: Data(json.utf8))
        let packages = payload.installedPackages()

        let ffmpeg = try #require(packages.first { $0.name == "ffmpeg" })
        #expect(ffmpeg.latestVersion == "9.0.1_1")
        #expect(ffmpeg.installedVersions == ["9.0.1"])
        // Zero and absent revisions must not gain a suffix.
        #expect(packages.first { $0.name == "wget" }?.latestVersion == "1.25.0")
        #expect(packages.first { $0.name == "aria2" }?.latestVersion == "1.37.0")
    }

    @Test func `unusable revision values fall back to the plain stable version`() throws {
        let json = """
        {
          "formulae": [
            { "name": "alpha", "versions": { "stable": "2.0.0" }, "revision": "1" },
            { "name": "beta", "versions": { "stable": "3.0.0" }, "revision": null },
            { "name": "gamma", "revision": 4 }
          ],
          "casks": []
        }
        """

        let payload = try JSONDecoder().decode(BrewInfoJSON.self, from: Data(json.utf8))
        let packages = payload.installedPackages()

        #expect(packages.first { $0.name == "alpha" }?.latestVersion == "2.0.0")
        #expect(packages.first { $0.name == "beta" }?.latestVersion == "3.0.0")
        // No stable version to hang a revision off: still empty, not "_4".
        #expect(packages.first { $0.name == "gamma" }?.latestVersion == "")
    }

    @Test func `installedPackages sorts case-insensitively`() throws {
        let json = """
        {
          "formulae": [{ "name": "Zsh" }, { "name": "aria2" }],
          "casks": [{ "token": "Firefox" }]
        }
        """

        let payload = try JSONDecoder().decode(BrewInfoJSON.self, from: Data(json.utf8))

        #expect(payload.installedPackages().map(\.name) == ["aria2", "Firefox", "Zsh"])
    }
}
