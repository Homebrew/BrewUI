//
//  BrewInstalledPackagesRepository.swift
//  Brew
//

import Foundation

struct BrewInstalledPackagesRepository: InstalledPackagesRepository, InstalledInventoryReading {
    private let commandRunner: BrewCommandRunning
    private let locator: any BrewExecutableLocating
    private let cache: InstalledInventoryCache

    init(
        commandRunner: BrewCommandRunning,
        locator: any BrewExecutableLocating,
        cache: InstalledInventoryCache,
    ) {
        self.commandRunner = commandRunner
        self.locator = locator
        self.cache = cache
    }

    /// Production wiring: real subprocess + default `brew` lookup.
    static func live(cache: InstalledInventoryCache) -> BrewInstalledPackagesRepository {
        BrewInstalledPackagesRepository(
            commandRunner: BrewCommandService(),
            locator: BrewExecutableLocator(),
            cache: cache,
        )
    }

    func loadInstalledPackages(forceRefresh: Bool = false) async throws -> [InstalledBrewPackage] {
        guard !forceRefresh else {
            return try await fetchInstalledPackages()
        }

        switch await cache.cachedPackages() {
        case let .fresh(packages):
            return packages
        case .stale, .empty:
            return try await fetchInstalledPackages()
        }
    }

    func installedPackageIDs() async -> Set<InstalledBrewPackage.ID> {
        let packages = await installedPackages()
        return Set(packages.map(\.id))
    }

    func installedPackages() async -> [InstalledBrewPackage] {
        guard let snapshot = await cache.currentSnapshot() else {
            return []
        }
        return snapshot.packages
    }

    private func fetchInstalledPackages() async throws -> [InstalledBrewPackage] {
        let brew = try locator.findBrewExecutable()
        let output = try await runInstalledInfoJSON(executable: brew)
        let payload = try decodeInfoJSON(from: output)
        let packages = payload.installedPackages()
        let snapshot = InstalledInventorySnapshot(fetchedAt: .now, packages: packages)
        await cache.replace(snapshot)
        return packages
    }

    private func runInstalledInfoJSON(executable: URL) async throws -> String {
        let arguments = ["info", "--installed", "--json=v2"]
        let output = try await commandRunner.run(executableURL: executable, arguments: arguments)
        guard output.terminationStatus == 0 else {
            throw BrewCommandError.failed(exitCode: output.terminationStatus, stderr: output.standardError)
        }
        return output.standardOutput
    }

    private func decodeInfoJSON(from standardOutput: String) throws -> BrewInfoJSON {
        let data = Data(standardOutput.utf8)
        do {
            return try JSONDecoder().decode(BrewInfoJSON.self, from: data)
        } catch {
            throw BrewCommandError.launchFailed(
                underlying: String(
                    localized: "Failed to decode Homebrew JSON output.",
                    comment: "Installed tab JSON decode failure",
                ),
            )
        }
    }
}
