//
//  BrewPackageDetailsRepositoryTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct BrewPackageDetailsRepositoryTests {
    @Test @MainActor func `load maps formula details from brew info json`() async throws {
        let runner = MockBrewCommandRunner(responses: [
            ["info", "wget", "--json=v2"]: CommandOutput(
                standardOutput: formulaJSON,
                standardError: "",
                terminationStatus: 0,
            ),
        ])
        let repo = repository(commandRunner: runner)
        let details = try await repo.loadPackageDetails(named: "wget")
        let expected = InstalledPackageDetails(
            name: "wget",
            kind: .formula,
            description: "Internet file retriever",
            version: "1.24.5",
            installedVersions: ["1.24.5", "1.24.4"],
            homepage: "https://www.gnu.org/software/wget/",
            dependencies: ["libidn2", "openssl@3", "pkgconf"],
            outdated: true,
            availableVersion: "1.24.5",
        )
        #expect(details == expected)
    }

    @Test @MainActor func `load maps cask details with object style dependencies`() async throws {
        let runner = MockBrewCommandRunner(responses: [
            ["info", "slack", "--json=v2"]: CommandOutput(
                standardOutput: caskJSON,
                standardError: "",
                terminationStatus: 0,
            ),
        ])
        let repo = repository(commandRunner: runner)
        let details = try await repo.loadPackageDetails(named: "slack")
        #expect(details.name == "slack")
        #expect(details.kind == .cask)
        #expect(details.description == "Team communication and collaboration software")
        #expect(details.version == "4.41.105")
        #expect(details.installedVersions == ["4.41.105"])
        #expect(details.homepage == "https://slack.com/")
        #expect(Set(details.dependencies) == Set(["mas", "microsoft-auto-update", "ventura"]))
        #expect(details.outdated)
        #expect(details.availableVersion == "4.41.105")
    }

    @Test @MainActor func `load honors preferred kind when payload includes formula and cask`() async throws {
        let runner = MockBrewCommandRunner(responses: [
            ["info", "foo", "--json=v2"]: CommandOutput(
                standardOutput: mixedJSON,
                standardError: "",
                terminationStatus: 0,
            ),
        ])
        let repo = repository(commandRunner: runner)
        let details = try await repo.loadPackageDetails(named: "foo", preferredKind: .cask)
        #expect(details.kind == .cask)
    }

    @Test @MainActor func `load throws package not found when json payload has no entries`() async throws {
        let runner = MockBrewCommandRunner(responses: [
            ["info", "ghost", "--json=v2"]: CommandOutput(
                standardOutput: #"{"formulae":[],"casks":[]}"#,
                standardError: "",
                terminationStatus: 0,
            ),
        ])
        let repo = repository(commandRunner: runner)
        await #expect(throws: PackageDetailsRepositoryError.self) {
            try await repo.loadPackageDetails(named: "ghost")
        }
    }

    @Test @MainActor func `load throws invalid json output when payload cannot decode`() async {
        let runner = MockBrewCommandRunner(responses: [
            ["info", "wget", "--json=v2"]: CommandOutput(
                standardOutput: #"{"formulae": "not-an-array"}"#,
                standardError: "",
                terminationStatus: 0,
            ),
        ])
        let repo = repository(commandRunner: runner)
        await #expect(throws: PackageDetailsRepositoryError.self) {
            try await repo.loadPackageDetails(named: "wget")
        }
    }

    @Test @MainActor func `load surfaces brew command failed when exit code is non-zero`() async {
        let runner = MockBrewCommandRunner(responses: [
            ["info", "wget", "--json=v2"]: CommandOutput(
                standardOutput: "",
                standardError: "brew failed",
                terminationStatus: 1,
            ),
        ])
        let repo = repository(commandRunner: runner)
        await #expect(throws: BrewCommandError.self) {
            try await repo.loadPackageDetails(named: "wget")
        }
    }

    @Test @MainActor func `load throws executable not found when brew cannot be located`() async {
        let runner = MockBrewCommandRunner(responses: [:])
        let repo = repository(commandRunner: runner, locator: MissingBrewExecutableLocator())
        await #expect(throws: BrewLookupError.self) {
            try await repo.loadPackageDetails(named: "wget")
        }
    }
}

private func repository(
    commandRunner: BrewCommandRunning,
    locator: (any BrewExecutableLocating)? = nil,
) -> BrewPackageDetailsRepository {
    let resolvedLocator = locator
        ?? BrewExecutableLocator(
            overrideURL: InstalledPackagesTestSupport.fakeBrewExecutableURL,
        )
    return BrewPackageDetailsRepository(commandRunner: commandRunner, locator: resolvedLocator)
}

private let formulaJSON = #"""
{
  "formulae": [
    {
      "name": "wget",
      "desc": "Internet file retriever",
      "homepage": "https://www.gnu.org/software/wget/",
      "outdated": true,
      "versions": { "stable": "1.24.5" },
      "installed": [{ "version": "1.24.5" }, { "version": "1.24.4" }],
      "dependencies": ["libidn2", "openssl@3"],
      "build_dependencies": ["pkgconf"]
    }
  ],
  "casks": []
}
"""#

private let caskJSON = #"""
{
  "formulae": [],
  "casks": [
    {
      "token": "slack",
      "desc": "Team communication and collaboration software",
      "homepage": "https://slack.com/",
      "outdated": true,
      "version": "4.41.105",
      "installed": "4.41.105",
      "dependencies": {
        "formula": ["mas"],
        "cask": ["microsoft-auto-update"],
        "macos": ["ventura"]
      }
    }
  ]
}
"""#

private let mixedJSON = #"""
{
  "formulae": [
    {
      "name": "foo",
      "desc": "Formula foo",
      "versions": { "stable": "1.0.0" },
      "installed": [{ "version": "1.0.0" }]
    }
  ],
  "casks": [
    {
      "token": "foo",
      "desc": "Cask foo",
      "version": "2.0.0",
      "installed": "2.0.0"
    }
  ]
}
"""#
