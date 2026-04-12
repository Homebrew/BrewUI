//
//  BrewInstalledPackagesRepositoryTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct BrewInstalledPackagesRepositoryTests {
    @Test @MainActor func `load returns sorted snapshot for formula and cask stdout`() async throws {
        let runner = MockBrewCommandRunner(responses: InstalledPackagesTestSupport.listVersionsResponses(
            formulaStandardOutput: "b 2\na 1\n",
            caskStandardOutput: "zed 3\n",
        ))
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        let snap = try await repo.loadInstalledPackages()
        let expected = InstalledPackagesSnapshot(
            formulae: [
                InstalledPackageInfo(name: "a", version: "1"),
                InstalledPackageInfo(name: "b", version: "2"),
            ],
            casks: [InstalledPackageInfo(name: "zed", version: "3")],
        )
        #expect(snap == expected)
    }

    @Test @MainActor func `load throws when formula list exits non zero`() async throws {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.responsesFormulaListFailure(
                standardError: "boom",
                terminationStatus: 1,
            ),
        )
        let repo = InstalledPackagesTestSupport.repository(commandRunner: runner)
        await #expect(throws: BrewCommandError.self) {
            try await repo.loadInstalledPackages()
        }
    }

    @Test @MainActor func `load throws when cask list exits non zero after formula succeeds`() async throws {
        let runner = MockBrewCommandRunner(
            responses: InstalledPackagesTestSupport.responsesFormulaSuccessCaskFailure(
                formulaStandardOutput: "a 1\n",
                caskStandardError: "cask failed",
                caskTerminationStatus: 2,
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
