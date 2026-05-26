//
//  AppPreviewSupport.swift
//  Brew
//

import Foundation

nonisolated enum AppPreviewSupport {
    static let commandCenter = PreviewBrewCommandCenter()
    static let installedInventoryCache = InstalledInventoryCache()
    static let discoverTopPackagesSnapshot = DiscoverTopPackagesSnapshot(
        topFormulae: [
            DiscoveryBrewPackage(
                package: BrewPackage(
                    name: "git",
                    displayName: "git",
                    kind: .formula,
                    description: "",
                    homepage: "",
                    latestVersion: "",
                    dependencies: [],
                ),
                thirtyDayInstallCount: 420_000,
            ),
            DiscoveryBrewPackage(
                package: BrewPackage(
                    name: "node",
                    displayName: "node",
                    kind: .formula,
                    description: "",
                    homepage: "",
                    latestVersion: "",
                    dependencies: [],
                ),
                thirtyDayInstallCount: 360_000,
            ),
        ],
        topCasks: [
            DiscoveryBrewPackage(
                package: BrewPackage(
                    name: "iterm2",
                    displayName: "iterm2",
                    kind: .cask,
                    description: "",
                    homepage: "",
                    latestVersion: "",
                    dependencies: [],
                ),
                thirtyDayInstallCount: 180_000,
            ),
            DiscoveryBrewPackage(
                package: BrewPackage(
                    name: "docker",
                    displayName: "docker",
                    kind: .cask,
                    description: "",
                    homepage: "",
                    latestVersion: "",
                    dependencies: [],
                ),
                thirtyDayInstallCount: 160_000,
            ),
        ],
    )
    /// A single representative discovery package for previews that only need one row's worth of data.
    static let discoverPreviewPackage = DiscoveryBrewPackage(
        package: BrewPackage(
            name: "git",
            displayName: "git",
            kind: .formula,
            description: "Distributed revision control system",
            homepage: "https://git-scm.com",
            latestVersion: "2.46.1",
            dependencies: [],
        ),
        thirtyDayInstallCount: 420_000,
    )

    static let discoverFormulaeCatalogue: [BrewPackage] = [
        BrewPackage(
            name: "git",
            displayName: "git",
            kind: .formula,
            description: "Distributed revision control system",
            homepage: "https://git-scm.com",
            latestVersion: "2.46.1",
            dependencies: [],
        ),
        BrewPackage(
            name: "node",
            displayName: "node",
            kind: .formula,
            description: "JavaScript runtime built on V8",
            homepage: "https://nodejs.org",
            latestVersion: "22.14.0",
            dependencies: [],
        ),
    ]
    static let discoverCasksCatalogue: [BrewPackage] = [
        BrewPackage(
            name: "iterm2",
            displayName: "iTerm2",
            kind: .cask,
            description: "Terminal emulator and shell replacement",
            homepage: "https://iterm2.com",
            latestVersion: "3.5.0",
            dependencies: [],
        ),
        BrewPackage(
            name: "docker",
            displayName: "Docker",
            kind: .cask,
            description: "Build and share containerized applications",
            homepage: "https://www.docker.com",
            latestVersion: "4.39.0",
            dependencies: [],
        ),
    ]

    static let outdatedFormula = InstalledBrewPackage(
        package: BrewPackage(
            name: "git",
            displayName: "git",
            kind: .formula,
            description: "Distributed revision control system.",
            homepage: "https://git-scm.com",
            latestVersion: "2.46.1",
            dependencies: [.formula(name: "openssl@3"), .formula(name: "pcre2")],
        ),
        installedVersions: ["2.45.0"],
        outdated: true,
    )

    static let currentFormula = InstalledBrewPackage(
        package: BrewPackage(
            name: "node",
            displayName: "node",
            kind: .formula,
            description: "JavaScript runtime built on V8.",
            homepage: "https://nodejs.org",
            latestVersion: "22.14.0",
            dependencies: [.formula(name: "icu4c@76")],
        ),
        installedVersions: ["22.14.0"],
        outdated: false,
    )

    static let currentCask = InstalledBrewPackage(
        package: BrewPackage(
            name: "docker",
            displayName: "Docker",
            kind: .cask,
            description: "Build and share containerized applications.",
            homepage: "https://www.docker.com",
            latestVersion: "4.39.0",
            dependencies: [],
        ),
        installedVersions: ["4.39.0"],
        outdated: false,
    )

    static let installedPackages: [InstalledBrewPackage] = [
        outdatedFormula,
        currentFormula,
        InstalledBrewPackage(
            package: BrewPackage(
                name: "python",
                displayName: "python",
                kind: .formula,
                description: "Interpreted, interactive, object-oriented programming language.",
                homepage: "https://www.python.org",
                latestVersion: "3.13.2",
                dependencies: [.formula(name: "openssl@3"), .formula(name: "sqlite")],
            ),
            installedVersions: ["3.13.2"],
            outdated: false,
        ),
        InstalledBrewPackage(
            package: BrewPackage(
                name: "visual-studio-code",
                displayName: "Visual Studio Code",
                kind: .cask,
                description: "Open-source code editor.",
                homepage: "https://code.visualstudio.com",
                latestVersion: "1.99.0",
                dependencies: [],
            ),
            installedVersions: ["1.99.0"],
            outdated: false,
        ),
        currentCask,
    ]

    static let emptyPackages: [InstalledBrewPackage] = []

    static let installedDependentsByPackageID: [InstalledBrewPackage.ID: [InstalledBrewPackage]] = [
        outdatedFormula.id: [
            InstalledBrewPackage(
                package: BrewPackage(
                    name: "gh",
                    displayName: "gh",
                    kind: .formula,
                    description: "GitHub's official command line tool.",
                    homepage: "https://cli.github.com",
                    latestVersion: "2.67.0",
                    dependencies: [.formula(name: "git")],
                ),
                installedVersions: ["2.67.0"],
                outdated: false,
            ),
        ],
    ]

    static let installedInventoryIDs: Set<InstalledBrewPackage.ID> = Set(
        installedPackages.map(\.id) + [
            .formula(name: "openssl@3"),
            .formula(name: "pcre2"),
            .formula(name: "icu4c@76"),
        ],
    )

    @MainActor
    static func makeInstalledPackagesRepository(
        packages: [InstalledBrewPackage] = installedPackages,
    ) -> BrewInstalledPackagesRepository {
        BrewInstalledPackagesRepository.previewLoaded(packages)
    }

    @MainActor
    static func makeInstalledViewModel(
        packages: [InstalledBrewPackage] = installedPackages,
    ) -> InstalledViewModel {
        InstalledViewModel(repository: makeInstalledPackagesRepository(packages: packages))
    }

    @MainActor
    static func makeInstalledDependentsRepository() -> any InstalledDependentsRepository {
        PreviewInstalledDependentsRepository(
            dependentsByPackageID: installedDependentsByPackageID,
        )
    }

    @MainActor
    static func makeInstalledInventoryReading() -> any InstalledInventoryReading {
        makeInstalledPackagesRepository()
    }

    @MainActor
    static func makeDiscoverPackagesRepository() -> any DiscoverPackagesRepository {
        PreviewDiscoverPackagesRepository(snapshot: discoverTopPackagesSnapshot)
    }

    @MainActor
    static func makeDiscoverListRowViewModel(
        package: DiscoveryBrewPackage = discoverPreviewPackage,
        showsInstallMetrics: Bool = true,
    ) -> DiscoverListRowViewModel {
        DiscoverListRowViewModel(
            discoveryPackage: package,
            installedRepository: makeInstalledPackagesRepository(),
            brewCommandCenter: NoopBrewCommandCenter(executionContext: .noopForTestingAndPreviews()),
            showsInstallMetrics: showsInstallMetrics,
        )
    }

    @MainActor
    static func makeDiscoverCatalogueRepository() -> any CatalogueRepository {
        PreviewDiscoverCatalogueRepository(
            formulaCatalogue: discoverFormulaeCatalogue,
            caskCatalogue: discoverCasksCatalogue,
        )
    }
}

actor PreviewBrewCommandCenter: BrewCommandCenter {
    func phase(for _: BrewOperationID) async -> BrewOperationPhase {
        .idle
    }

    func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    func isActive(id _: BrewOperationID) async -> Bool {
        false
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
            continuation.yield(.idle)
            continuation.finish()
        }
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream<(BrewOperationID, BrewOperationPhase)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    func submit(
        id _: BrewOperationID,
        command _: any BrewMutatingCommand,
    ) async throws {}
}

struct PreviewInstalledDependentsRepository: InstalledDependentsRepository {
    let dependentsByPackageID: [InstalledBrewPackage.ID: [InstalledBrewPackage]]

    func installedDependents(for packageID: InstalledBrewPackage.ID) async -> [InstalledBrewPackage] {
        dependentsByPackageID[packageID] ?? []
    }
}

struct PreviewDiscoverPackagesRepository: DiscoverPackagesRepository {
    let snapshot: DiscoverTopPackagesSnapshot

    func loadTopPackages(
        limit _: Int,
        window _: BrewAnalyticsWindow,
    ) async throws -> DiscoverTopPackagesSnapshot {
        snapshot
    }
}

struct PreviewDiscoverCatalogueRepository: CatalogueRepository {
    let formulaCatalogue: [BrewPackage]
    let caskCatalogue: [BrewPackage]

    func package(for reference: HomebrewPackageID) async throws -> BrewPackage? {
        let packages = reference.kind == .formula ? formulaCatalogue : caskCatalogue
        return packages.first { $0.id == reference }
    }

    func searchPackages(matching query: String, limit: Int) async throws -> [BrewPackage] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, limit > 0 else {
            return []
        }
        let matches = (formulaCatalogue + caskCatalogue).filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.displayName.localizedCaseInsensitiveContains(trimmedQuery)
        }
        return Array(matches.prefix(limit))
    }
}
