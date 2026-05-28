//
//  BrewSampleData.swift
//  BrewCoreTestSupport
//

import BrewCore
import Foundation

/// Shared model fixtures for previews and tests. Pure `BrewCore` value types — no repositories, no I/O.
public enum BrewSampleData {
    public static let discoverTopPackagesSnapshot = DiscoverTopPackagesSnapshot(
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
    public static let discoverPreviewPackage = DiscoveryBrewPackage(
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

    public static let discoverFormulaeCatalogue: [BrewPackage] = [
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

    public static let discoverCasksCatalogue: [BrewPackage] = [
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

    public static let outdatedFormula = InstalledBrewPackage(
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

    public static let currentFormula = InstalledBrewPackage(
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

    public static let currentCask = InstalledBrewPackage(
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

    public static let installedPackages: [InstalledBrewPackage] = [
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

    public static let emptyPackages: [InstalledBrewPackage] = []

    public static let installedDependentsByPackageID: [InstalledBrewPackage.ID: [InstalledBrewPackage]] = [
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

    public static let installedInventoryIDs: Set<InstalledBrewPackage.ID> = Set(
        installedPackages.map(\.id) + [
            .formula(name: "openssl@3"),
            .formula(name: "pcre2"),
            .formula(name: "icu4c@76"),
        ],
    )
}
