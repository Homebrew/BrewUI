//
//  BrewInstalledPackagesCacheTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

struct BrewInstalledPackagesCacheTests {
    @Test @MainActor func `load returns cached packages when snapshot is fresh`() async throws {
        let cache = InstalledInventoryCache()
        let runner = CountingInstalledInfoJSONRunner()
        let repository = InstalledPackagesTestSupport.repository(commandRunner: runner, cache: cache)

        let first = try await repository.loadInstalledPackages()
        let second = try await repository.loadInstalledPackages()

        #expect(first.map(\.name) == ["git"])
        #expect(second.map(\.name) == ["git"])
        #expect(runner.loadCallCount == 1)
    }

    @Test @MainActor func `load refetches when forceRefresh is true`() async throws {
        let cache = InstalledInventoryCache()
        let runner = CountingInstalledInfoJSONRunner()
        let repository = InstalledPackagesTestSupport.repository(commandRunner: runner, cache: cache)

        _ = try await repository.loadInstalledPackages()
        _ = try await repository.loadInstalledPackages(forceRefresh: true)

        #expect(runner.loadCallCount == 2)
    }

    @Test @MainActor func `load refetches when snapshot is stale`() async throws {
        let cache = InstalledInventoryCache()
        let runner = CountingInstalledInfoJSONRunner()
        let repository = InstalledPackagesTestSupport.repository(commandRunner: runner, cache: cache)
        let staleSnapshot = InstalledInventorySnapshot(
            fetchedAt: Date(timeIntervalSince1970: 0),
            packages: [.fixture(name: "stale", kind: .formula)],
        )
        await cache.replace(staleSnapshot)

        let packages = try await repository.loadInstalledPackages()

        #expect(packages.map(\.name) == ["git"])
        #expect(runner.loadCallCount == 1)
    }

    @Test @MainActor func `inventory reading exposes cached ids`() async {
        let cache = InstalledInventoryCache()
        let packages = [
            BrewPackage.fixture(name: "openssl@3", kind: .formula),
            BrewPackage.fixture(name: "wget", kind: .formula, dependencies: [.formula(name: "openssl@3")]),
        ]
        await cache.replace(InstalledInventorySnapshot(fetchedAt: .now, packages: packages))
        let repository = InstalledPackagesTestSupport.repository(
            commandRunner: MockBrewCommandRunner(responses: [:]),
            cache: cache,
        )

        let installedIDs = await repository.installedPackageIDs()
        #expect(installedIDs == Set(packages.map(\.id)))
    }
}

private final class CountingInstalledInfoJSONRunner: BrewCommandRunning, @unchecked Sendable {
    private(set) var loadCallCount = 0

    func run(executableURL _: URL, arguments: [String]) async throws -> CommandOutput {
        guard arguments == ["info", "--installed", "--json=v2"] else {
            throw BrewCommandError.failed(exitCode: 99, stderr: "unmocked: \(arguments.joined(separator: " "))")
        }
        loadCallCount += 1
        return CommandOutput(
            standardOutput: """
            {
              "formulae": [
                { "name": "git", "versions": { "stable": "2.0.0" }, "installed": [{ "version": "1.0.0" }] }
              ],
              "casks": []
            }
            """,
            standardError: "",
            terminationStatus: 0,
        )
    }
}
