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
