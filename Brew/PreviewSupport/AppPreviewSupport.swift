//
//  AppPreviewSupport.swift
//  Brew
//

import Foundation

enum AppPreviewSupport {
    static let commandCenter = PreviewBrewCommandCenter()
    static let installedInventoryCache = InstalledInventoryCache()

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
        installedPackages.map(\.id) + ["formula:openssl@3", "formula:pcre2", "formula:icu4c@76"],
    )

    @MainActor
    static func makeInstalledViewModel(
        packages: [InstalledBrewPackage] = installedPackages,
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
    let packages: [InstalledBrewPackage]

    func loadInstalledPackages(forceRefresh _: Bool) async throws -> [InstalledBrewPackage] {
        packages
    }
}

struct PreviewInstalledDependentsRepository: InstalledDependentsRepository {
    let dependentsByPackageID: [InstalledBrewPackage.ID: [InstalledBrewPackage]]

    func installedDependents(for packageID: InstalledBrewPackage.ID) async -> [InstalledBrewPackage] {
        dependentsByPackageID[packageID] ?? []
    }
}

struct PreviewInstalledInventoryReading: InstalledInventoryReading {
    let knownInstalledPackageIDs: Set<InstalledBrewPackage.ID>

    func installedPackageIDs() async -> Set<InstalledBrewPackage.ID> {
        knownInstalledPackageIDs
    }
}
