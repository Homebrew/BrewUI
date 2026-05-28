//
//  BrewInstalledPackagesCacheTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
import BrewCoreTestSupport
import BrewNetworking
import BrewRepositories
@testable import BrewRepositoriesLive
import BrewRepositoriesTestSupport
import BrewServicesTestSupport
import Foundation
import Testing

struct BrewInstalledPackagesCacheTests {
    @Test @MainActor func `load returns cached packages when snapshot is fresh`() async {
        let cache = InstalledInventoryCache()
        let runner = CountingInstalledInfoJSONRunner()
        let repository = InstalledPackagesTestSupport.repository(commandRunner: runner, cache: cache)

        await repository.load()
        let first = repository.state.value ?? []
        await repository.load()
        let second = repository.state.value ?? []

        #expect(first.map(\.name) == ["git"])
        #expect(second.map(\.name) == ["git"])
        #expect(runner.loadCallCount == 1)
    }

    @Test @MainActor func `load refetches when forceRefresh is true`() async {
        let cache = InstalledInventoryCache()
        let runner = CountingInstalledInfoJSONRunner()
        let repository = InstalledPackagesTestSupport.repository(commandRunner: runner, cache: cache)

        await repository.load()
        await repository.load(forceRefresh: true)

        #expect(runner.loadCallCount == 2)
    }

    @Test @MainActor func `load refetches when snapshot is stale`() async {
        let cache = InstalledInventoryCache()
        let runner = CountingInstalledInfoJSONRunner()
        let repository = InstalledPackagesTestSupport.repository(commandRunner: runner, cache: cache)
        let staleSnapshot = InstalledInventorySnapshot(
            fetchedAt: Date(timeIntervalSince1970: 0),
            packages: [.fixture(name: "stale", kind: .formula)],
        )
        await cache.replace(staleSnapshot)

        await repository.load()

        #expect(repository.state.value?.map(\.name) == ["git"])
        #expect(runner.loadCallCount == 1)
    }

    @Test @MainActor func `inventory reading exposes cached ids`() async {
        let cache = InstalledInventoryCache()
        let packages = [
            InstalledBrewPackage.fixture(name: "openssl@3", kind: .formula),
            InstalledBrewPackage.fixture(name: "wget", kind: .formula, dependencies: [.formula(name: "openssl@3")]),
        ]
        await cache.replace(InstalledInventorySnapshot(fetchedAt: .now, packages: packages))
        let repository = InstalledPackagesTestSupport.repository(
            commandRunner: MockBrewCommandRunner(responses: [:]),
            cache: cache,
        )

        await repository.load()
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
