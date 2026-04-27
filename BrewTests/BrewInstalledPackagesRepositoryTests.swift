//
//  BrewInstalledPackagesRepositoryTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct BrewInstalledPackagesRepositoryTests {
    @Test @MainActor func `load returns sorted snapshot for mixed formula and cask json payload`() async throws {
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
        let snap = try await repo.loadInstalledPackages()
        let expected = InstalledPackagesSnapshot(
            formulae: [
                InstalledPackageInfo(name: "aria2", version: "2.0.0"),
                InstalledPackageInfo(name: "wget", version: "1.24.5"),
            ],
            casks: [InstalledPackageInfo(name: "zed", version: "1.2.4")],
        )
        #expect(snap == expected)
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
        let snap = try await repo.loadInstalledPackages()
        let expected = InstalledPackagesSnapshot(
            formulae: [
                InstalledPackageInfo(name: "alpha", version: "1.2.3"),
                InstalledPackageInfo(name: "beta", version: "2.0.0"),
                InstalledPackageInfo(name: "gamma", version: "3.1.0"),
            ],
            casks: [
                InstalledPackageInfo(name: "charlie", version: "6.0.0"),
                InstalledPackageInfo(name: "delta", version: "5.0.0"),
                InstalledPackageInfo(name: "echo", version: "4.0.1"),
            ],
        )
        #expect(snap == expected)
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
        let snap = try await repo.loadInstalledPackages()

        let expected = InstalledPackagesSnapshot(
            formulae: [
                InstalledPackageInfo(name: "a", version: nil),
                InstalledPackageInfo(name: "b", version: nil),
            ],
            casks: [
                InstalledPackageInfo(name: "cask-one", version: nil),
                InstalledPackageInfo(name: "cask-two", version: nil),
            ],
        )
        #expect(snap == expected)
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
        let snap = try await repo.loadInstalledPackages()
        #expect(snap == InstalledPackagesSnapshot(formulae: [], casks: []))
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
