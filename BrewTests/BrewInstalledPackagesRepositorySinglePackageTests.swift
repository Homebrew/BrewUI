//
//  BrewInstalledPackagesRepositorySinglePackageTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct BrewInstalledPackageLookupTests {
    @Test @MainActor func `single package load decodes formula info for matching name`() async throws {
        let json = """
        {
          "formulae": [
            {
              "name": "wget",
              "outdated": true,
              "versions": { "stable": "1.26.0" },
              "installed": [{ "version": "1.24.5" }]
            }
          ],
          "casks": []
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.packageInfoJSONResponse(
                kind: .formula,
                name: "wget",
                standardOutput: json,
            ),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let package = try await repo.loadInstalledPackage(kind: .formula, named: "wget")
        #expect(
            package == InstalledPackageInfo(
                name: "wget",
                version: "1.24.5",
                upgradeToVersion: "1.26.0",
            ),
        )
    }

    @Test @MainActor func `single package load decodes cask info for matching token`() async throws {
        let json = """
        {
          "formulae": [],
          "casks": [
            {
              "token": "zed",
              "version": "1.3.0",
              "installed": "1.2.4",
              "outdated": true
            }
          ]
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.packageInfoJSONResponse(
                kind: .cask,
                name: "zed",
                standardOutput: json,
            ),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let package = try await repo.loadInstalledPackage(kind: .cask, named: "zed")
        #expect(
            package == InstalledPackageInfo(
                name: "zed",
                version: "1.2.4",
                upgradeToVersion: "1.3.0",
            ),
        )
    }

    @Test @MainActor func `single package load throws package not found for missing name`() async throws {
        let json = """
        {
          "formulae": [
            { "name": "other", "versions": { "stable": "1.0.0" }, "installed": [{ "version": "1.0.0" }] }
          ],
          "casks": []
        }
        """
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.packageInfoJSONResponse(
                kind: .formula,
                name: "missing",
                standardOutput: json,
            ),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        await #expect(throws: InstalledPackagesRepositoryError.self) {
            try await repo.loadInstalledPackage(kind: .formula, named: "missing")
        }
    }
}
