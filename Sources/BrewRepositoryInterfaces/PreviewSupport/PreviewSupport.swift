//
//  PreviewSupport.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

/// Ready-made repository fakes + a small sample data set for **SwiftUI previews only**.
///
/// Lives here (a production library) rather than a test-support library so feature packages can render
/// previews without depending on test scaffolding. Everything is built on the ``Fakes`` no-op
/// conformances, so it never touches `brew`, the network, or disk. Not intended for production code
/// paths — only `#Preview` blocks. Richer fixtures for unit tests live in `BrewCoreTestSupport`.
public enum PreviewSupport {
    public static let commandCenter = StubBrewCommandCenter()
    public static let mutatingCommandFactory = StubMutatingCommandFactory()

    public static let emptyPackages: [InstalledBrewPackage] = []

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

    @MainActor
    public static func makeInstalledPackagesRepository(
        packages: [InstalledBrewPackage] = PreviewSupport.installedPackages,
    ) -> StubInstalledPackagesRepository {
        StubInstalledPackagesRepository(packages: packages)
    }

    @MainActor
    public static func makeInstalledDependentsRepository() -> any InstalledDependentsRepository {
        StubDependentsRepository(dependentsByPackageID: dependentsByPackageID)
    }

    @MainActor
    public static func makeInstalledInventoryReading() -> any InstalledInventoryReading {
        makeInstalledPackagesRepository()
    }

    @MainActor
    public static func makeDiscoverPackagesRepository() -> any DiscoverPackagesRepository {
        StubDiscoverPackagesRepository(snapshot: discoverSnapshot)
    }

    @MainActor
    public static func makeDiscoverCatalogueRepository() -> any CatalogueRepository {
        StubCatalogueRepository(formulaCatalogue: formulaCatalogue, caskCatalogue: caskCatalogue)
    }

    @MainActor
    public static func makeDoctorRepository(report: DoctorReport = doctorReport) -> any DoctorRepository {
        StubDoctorRepository(report: report)
    }

    public static let healthyDoctorReport = DoctorReport(issues: [])

    /// A sample report with a runnable cleanup fix and an advisory-only issue (no `brew` fix).
    public static let doctorReport = DoctorReport(issues: [
        DoctorIssue(
            title: "Some cached downloads are stale.",
            severity: .caution,
            blocks: [
                DoctorBlock(
                    id: 0,
                    caption: nil,
                    content: .prose(["Run brew cleanup to remove them."]),
                ),
                DoctorBlock(
                    id: 1,
                    caption: nil,
                    content: .command([
                        DoctorFixStep(displayCommand: "brew cleanup", arguments: ["cleanup"], needsAdmin: false),
                    ]),
                ),
            ],
            rawBody: "Run brew cleanup to remove them.\n  brew cleanup",
        ),
        DoctorIssue(
            title: "Some installed formulae are deprecated or disabled.",
            severity: .caution,
            blocks: [
                DoctorBlock(
                    id: 0,
                    caption: nil,
                    content: .prose(["You should find replacements for the following formulae:"]),
                ),
                DoctorBlock(
                    id: 1,
                    caption: "You should find replacements for the following formulae:",
                    content: .data(["macvim"]),
                ),
            ],
            rawBody: "You should find replacements for the following formulae:\n  macvim",
        ),
    ])

    @MainActor
    public static func makeConfigRepository() -> any ConfigRepository {
        StubConfigRepository(snapshot: configSnapshot)
    }

    @MainActor
    public static func makeEnvFileRepository() -> any EnvFileRepository {
        StubEnvFileRepository(file: brewEnvFile)
    }

    public static let brewEnvFile = BrewEnvFile(lines: [
        .comment("# Managed by BrewUI — feel free to edit"),
        .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
        .entry(key: "HOMEBREW_NO_AUTO_UPDATE", value: "1"),
        .entry(key: "HOMEBREW_MAKE_JOBS", value: "8"),
    ])

    public static let configSnapshot = BrewConfigSnapshot(
        entries: [
            BrewConfigEntry(key: "HOMEBREW_VERSION", value: "4.3.0"),
            BrewConfigEntry(key: "ORIGIN", value: "https://github.com/Homebrew/brew"),
            BrewConfigEntry(key: "HEAD", value: "a1b2c3d4"),
            BrewConfigEntry(key: "Last commit", value: "3 days ago"),
            BrewConfigEntry(key: "HOMEBREW_PREFIX", value: "/opt/homebrew"),
            BrewConfigEntry(
                key: "Homebrew Ruby",
                value: "3.3.0 => /opt/homebrew/Library/Homebrew/vendor/portable-ruby/3.3.0/bin/ruby",
            ),
            BrewConfigEntry(key: "HOMEBREW_CASK_OPTS", value: "[]"),
            BrewConfigEntry(key: "HOMEBREW_DOWNLOAD_CONCURRENCY", value: "auto"),
            BrewConfigEntry(key: "HOMEBREW_MAKE_JOBS", value: "16"),
            BrewConfigEntry(key: "CPU", value: "16-core 64-bit arm_brava"),
            BrewConfigEntry(key: "Clang", value: "17.0.0 build 1700"),
            BrewConfigEntry(key: "Git", value: "2.50.1 => /usr/bin/git"),
            BrewConfigEntry(key: "macOS", value: "15.4-arm64"),
            BrewConfigEntry(key: "CLT", value: "16.4.0.0.1.1747106510"),
            BrewConfigEntry(key: "Xcode", value: "16.4"),
            BrewConfigEntry(key: "Rosetta 2", value: "false"),
        ],
        environment: [
            BrewConfigEntry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
            BrewConfigEntry(key: "HOMEBREW_PREFIX", value: "/opt/homebrew"),
        ],
    )

    // MARK: - Backing sample data (preview-only)

    public static let installedPackages: [InstalledBrewPackage] = [
        outdatedFormula,
        InstalledBrewPackage(
            package: BrewPackage(
                name: "node",
                displayName: "node",
                kind: .formula,
                description: "JavaScript runtime built on V8.",
                homepage: "https://nodejs.org",
                latestVersion: "22.14.0",
                dependencies: [],
            ),
            installedVersions: ["22.14.0"],
            outdated: false,
        ),
        currentCask,
    ]

    private static let dependentsByPackageID: [InstalledBrewPackage.ID: [InstalledBrewPackage]] = [
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

    private static let formulaCatalogue: [BrewPackage] = [
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

    private static let caskCatalogue: [BrewPackage] = [
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

    private static let discoverSnapshot = DiscoverTopPackagesSnapshot(
        topFormulae: [
            DiscoveryBrewPackage(
                package: formulaCatalogue[0],
                thirtyDayInstallCount: 420_000,
            ),
            DiscoveryBrewPackage(
                package: formulaCatalogue[1],
                thirtyDayInstallCount: 360_000,
            ),
        ],
        topCasks: [
            DiscoveryBrewPackage(
                package: caskCatalogue[0],
                thirtyDayInstallCount: 160_000,
            ),
        ],
    )
}
