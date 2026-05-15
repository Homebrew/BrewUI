//
//  BrewInstalledPackagesRepositoryTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct BrewInstalledPackagesRepositoryTests {
    @Test @MainActor func `load returns sorted packages for mixed formula and cask json payload`() async throws {
        let json = """
        {
          "formulae": [
            { "name": "wget", "versions": { "stable": "1.0.0" }, "installed": [{ "version": "1.24.5" }] },
            { "name": "aria2", "versions": { "stable": "2.0.0" }, "installed": [] }
          ],
          "casks": [
            { "token": "zed", "version": "1.2.3", "installed": "1.2.4" }
          ]
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(standardOutput: json),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let packages = try await repo.loadInstalledPackages()

        #expect(packages.map(\.name) == ["aria2", "wget", "zed"])

        let aria2 = try #require(package(named: "aria2", in: packages))
        #expect(aria2.kind == .formula)
        #expect(aria2.latestVersion == "2.0.0")
        #expect(aria2.installedVersions.isEmpty)

        let zed = try #require(package(named: "zed", in: packages))
        #expect(zed.kind == .cask)
        #expect(zed.latestVersion == "1.2.3")
        #expect(zed.installedVersions == ["1.2.4"])
    }

    @Test @MainActor func `load handles mixed payload version fallback rules`() async throws {
        let json = """
        {
          "formulae": [
            {
              "name": "alpha",
              "versions": { "stable": "9.9.9" },
              "installed": [{ "version": "   " }, { "version": "1.2.3" }]
            },
            {
              "name": "beta",
              "versions": { "stable": "2.0.0" },
              "installed": [{ "version": "" }]
            },
            {
              "name": "gamma",
              "installed": [{ "version": "3.1.0" }]
            }
          ],
          "casks": [
            { "token": "echo", "version": "4.0.0", "installed": ["", "4.0.1"] },
            { "token": "delta", "version": "5.0.0", "installed": "" },
            { "token": "charlie", "installed": "6.0.0" }
          ]
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(standardOutput: json),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let packages = try await repo.loadInstalledPackages()

        #expect(packages.map(\.name) == ["alpha", "beta", "charlie", "delta", "echo", "gamma"])

        let alpha = try #require(package(named: "alpha", in: packages))
        #expect(alpha.latestVersion == "9.9.9")
        #expect(alpha.installedVersions == ["1.2.3"])

        let beta = try #require(package(named: "beta", in: packages))
        #expect(beta.latestVersion == "2.0.0")
        #expect(beta.installedVersions.isEmpty)

        let gamma = try #require(package(named: "gamma", in: packages))
        #expect(gamma.latestVersion.isEmpty)
        #expect(gamma.installedVersions == ["3.1.0"])

        let echo = try #require(package(named: "echo", in: packages))
        #expect(echo.latestVersion == "4.0.0")
        #expect(echo.installedVersions == ["4.0.1"])

        let delta = try #require(package(named: "delta", in: packages))
        #expect(delta.latestVersion == "5.0.0")
        #expect(delta.installedVersions.isEmpty)

        let charlie = try #require(package(named: "charlie", in: packages))
        #expect(charlie.latestVersion.isEmpty)
        #expect(charlie.installedVersions == ["6.0.0"])
    }

    @Test @MainActor func `load trims strings and deduplicates mapped dependencies`() async throws {
        let json = """
        {
          "formulae": [
            {
              "name": "deps-formula",
              "desc": "  formula desc  ",
              "homepage": " https://example.com ",
              "dependencies": ["openssl", ""],
              "build_dependencies": ["make", "openssl"],
              "recommended_dependencies": ["curl", " make "],
              "optional_dependencies": ["  sqlite ", ""],
              "versions": { "stable": "1.0.0" },
              "installed": [{ "version": "1.0.0" }]
            }
          ],
          "casks": [
            {
              "token": "deps-cask",
              "desc": "  cask desc  ",
              "homepage": " https://example.org ",
              "version": "2.0.0",
              "installed": ["2.0.0"],
              "dependencies": {
                "formula": [" git ", ""],
                "cask": ["docker", "git"]
              }
            }
          ]
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(standardOutput: json),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let packages = try await repo.loadInstalledPackages()

        let formula = try #require(package(named: "deps-formula", in: packages))
        #expect(formula.description == "formula desc")
        #expect(formula.homepage == "https://example.com")
        #expect(formula.dependencies == [.formula(name: "openssl")])

        let cask = try #require(package(named: "deps-cask", in: packages))
        #expect(cask.description == "cask desc")
        #expect(cask.homepage == "https://example.org")
        #expect(Set(cask.dependencies) == Set([.formula(name: "git"), .cask(token: "docker"), .cask(token: "git")]))
        #expect(cask.dependencies.count == 3)
    }

    @Test @MainActor func `load maps cask depends_on formula and cask keys and ignores macos`() async throws {
        let json = """
        {
          "formulae": [],
          "casks": [
            {
              "token": "beid-viewer",
              "installed": ["1.0.0"],
              "depends_on": {
                "macos": {},
                "cask": ["beid-token"]
              }
            },
            {
              "token": "beutl",
              "installed": ["2.0.0"],
              "depends_on": {
                "macos": { ">=": ["12"] },
                "formula": ["ffmpeg@6"]
              }
            }
          ]
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(standardOutput: json),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let packages = try await repo.loadInstalledPackages()

        let beidViewer = try #require(package(named: "beid-viewer", in: packages))
        #expect(beidViewer.dependencies == [.cask(token: "beid-token")])

        let beutl = try #require(package(named: "beutl", in: packages))
        #expect(beutl.dependencies == [.formula(name: "ffmpeg@6")])
    }

    @Test @MainActor func `load tolerates optional and missing fields in json payload`() async throws {
        let json = """
        {
          "formulae": [
            { "name": "a", "installed": [{ "version": "" }] },
            { "name": "b" }
          ],
          "casks": [
            { "token": "cask-one", "installed": [""] },
            { "token": "cask-two" }
          ]
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(standardOutput: json),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let packages = try await repo.loadInstalledPackages()
        #expect(packages.count == 4)
    }

    @Test @MainActor func `load tolerates invalid field types by treating sections as empty`() async throws {
        let json = """
        {
          "formulae": "not-an-array",
          "casks": { "token": "not-an-array" }
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(standardOutput: json),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let packages = try await repo.loadInstalledPackages()
        #expect(packages == [])
    }

    @Test @MainActor func `load throws when installed info exits non zero`() async throws {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.responsesInstalledInfoFailure(
                standardError: "boom",
                terminationStatus: 1,
            ),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        await #expect(throws: BrewCommandError.self) {
            try await repo.loadInstalledPackages()
        }
    }

    @Test @MainActor func `load throws when installed info json is invalid`() async throws {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.installedInfoJSONResponse(
                standardOutput: "{ this-is-not-json }",
            ),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        await #expect(throws: BrewCommandError.self) {
            try await repo.loadInstalledPackages()
        }
    }

    @Test @MainActor func `load throws BrewLookupError when locator fails`() async throws {
        let runner = MockBrewCommandRunner(responses: [:])
        let repo = InstalledPackagesTestSupport.repository(
            commandRunner: runner,
            locator: MissingBrewExecutableLocator(),
        )
        await #expect(throws: BrewLookupError.self) {
            try await repo.loadInstalledPackages()
        }
    }
}

@MainActor
private func package(named name: String, in packages: [BrewPackage]) -> BrewPackage? {
    packages.first { $0.name == name }
}
