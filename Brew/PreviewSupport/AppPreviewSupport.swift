//
//  AppPreviewSupport.swift
//  Brew
//

import Foundation

enum AppPreviewSupport {
    static let commandCenter = PreviewBrewCommandCenter()
    static let installedInventoryCache = InstalledInventoryCache()

    static let outdatedFormula = BrewPackage(
        name: "git",
        displayName: "git",
        kind: .formula,
        description: "Distributed revision control system.",
        homepage: "https://git-scm.com",
        latestVersion: "2.46.1",
        installedVersions: ["2.45.0"],
        dependencies: [.formula(name: "openssl@3"), .formula(name: "pcre2")],
        outdated: true,
    )

    static let currentFormula = BrewPackage(
        name: "node",
        displayName: "node",
        kind: .formula,
        description: "JavaScript runtime built on V8.",
        homepage: "https://nodejs.org",
        latestVersion: "22.14.0",
        installedVersions: ["22.14.0"],
        dependencies: [.formula(name: "icu4c@76")],
        outdated: false,
    )

    static let currentCask = BrewPackage(
        name: "docker",
        displayName: "Docker",
        kind: .cask,
        description: "Build and share containerized applications.",
        homepage: "https://www.docker.com",
        latestVersion: "4.39.0",
        installedVersions: ["4.39.0"],
        dependencies: [],
        outdated: false,
    )

    static let installedPackages: [BrewPackage] = [
        outdatedFormula,
        currentFormula,
        BrewPackage(
            name: "python",
            displayName: "python",
            kind: .formula,
            description: "Interpreted, interactive, object-oriented programming language.",
            homepage: "https://www.python.org",
            latestVersion: "3.13.2",
            installedVersions: ["3.13.2"],
            dependencies: [.formula(name: "openssl@3"), .formula(name: "sqlite")],
            outdated: false,
        ),
        BrewPackage(
            name: "visual-studio-code",
            displayName: "Visual Studio Code",
            kind: .cask,
            description: "Open-source code editor.",
            homepage: "https://code.visualstudio.com",
            latestVersion: "1.99.0",
            installedVersions: ["1.99.0"],
            dependencies: [],
            outdated: false,
        ),
        currentCask,
    ]

    static let emptyPackages: [BrewPackage] = []

    static let installedDependentsByPackageID: [BrewPackage.ID: [BrewPackage]] = [
        outdatedFormula.id: [
            BrewPackage(
                name: "gh",
                displayName: "gh",
                kind: .formula,
                description: "GitHub's official command line tool.",
                homepage: "https://cli.github.com",
                latestVersion: "2.67.0",
                installedVersions: ["2.67.0"],
                dependencies: [.formula(name: "git")],
                outdated: false,
            ),
        ],
    ]

    static let installedInventoryIDs: Set<BrewPackage.ID> = Set(
        installedPackages.map(\.id) + ["formula:openssl@3", "formula:pcre2", "formula:icu4c@76"],
    )

    @MainActor
    static func makeInstalledViewModel(
        packages: [BrewPackage] = installedPackages,
        commandCenter: any BrewCommandCenter = commandCenter,
    ) -> InstalledViewModel {
        InstalledViewModel(
            repository: PreviewInstalledPackagesRepository(packages: packages),
            brewCommandCenter: commandCenter,
        )
    }

    @MainActor
    static func makeInstalledDependentsRepository() -> any InstalledDependentsRepository {
        PreviewInstalledDependentsRepository(
            dependentsByPackageID: installedDependentsByPackageID,
        )
    }

    @MainActor
    static func makeInstalledInventoryReading() -> any InstalledInventoryReading {
        PreviewInstalledInventoryReading(knownInstalledPackageIDs: installedInventoryIDs)
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

struct PreviewInstalledPackagesRepository: InstalledPackagesRepository {
    let packages: [BrewPackage]

    func loadInstalledPackages(forceRefresh _: Bool) async throws -> [BrewPackage] {
        packages
    }
}

struct PreviewInstalledDependentsRepository: InstalledDependentsRepository {
    let dependentsByPackageID: [BrewPackage.ID: [BrewPackage]]

    func installedDependents(for packageID: BrewPackage.ID) async -> [BrewPackage] {
        dependentsByPackageID[packageID] ?? []
    }
}

struct PreviewInstalledInventoryReading: InstalledInventoryReading {
    let knownInstalledPackageIDs: Set<BrewPackage.ID>

    func installedPackageIDs() async -> Set<BrewPackage.ID> {
        knownInstalledPackageIDs
    }
}
