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
        license: "LGPL-2.1-only",
        tap: "homebrew/core",
        installedOnRequest: true,
        pouredFromBottle: true,
        installDate: Date(timeIntervalSinceNow: -86400 * 30),
        linkedKeg: "2.45.0",
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
        tap: "homebrew/cask",
        installedOnRequest: true,
        linkedKeg: "4.39.0",
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

    @MainActor
    public static func makeConfigRepository() -> any ConfigRepository {
        StubConfigRepository(snapshot: configSnapshot)
    }

    @MainActor
    public static func makeAIModelManager() -> any AIModelManaging {
        StubAIModelManager()
    }
}

public extension PreviewSupport {
    static let deprecatedFormula = InstalledBrewPackage(
        package: BrewPackage(
            name: "mysql@8.0",
            displayName: "mysql@8.0",
            kind: .formula,
            description: "Open source relational database management system",
            homepage: "https://dev.mysql.com/doc/refman/8.0/en/",
            latestVersion: "8.0.46",
            dependencies: [],
        ),
        installedVersions: ["8.0.46"],
        outdated: false,
        license: "GPL-2.0-only",
        tap: "homebrew/core",
        installedOnRequest: true,
        pouredFromBottle: true,
        installDate: Date(timeIntervalSinceNow: -86400 * 14),
        linkedKeg: "8.0.46",
        deprecated: true,
    )

    /// Matches a typical `mysql@8.0` keg that is both deprecated and behind latest.
    static let deprecatedOutdatedFormula = InstalledBrewPackage(
        package: BrewPackage(
            name: "mysql@8.0",
            displayName: "mysql@8.0",
            kind: .formula,
            description: "Open source relational database management system",
            homepage: "https://dev.mysql.com/doc/refman/8.0/en/",
            latestVersion: "8.0.46",
            dependencies: [],
        ),
        installedVersions: ["8.0.43_3"],
        outdated: true,
        license: "GPL-2.0-only",
        tap: "homebrew/core",
        installedOnRequest: true,
        pouredFromBottle: true,
        installDate: Date(timeIntervalSinceNow: -86400 * 14),
        linkedKeg: "8.0.43_3",
        deprecated: true,
    )

    static let healthyDoctorReport = DoctorReport(issues: [])

    /// A sample report with a runnable cleanup fix and an advisory-only issue (no `brew` fix).
    static let doctorReport = DoctorReport(issues: [
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

    static let configSnapshot = BrewConfigSnapshot(
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

    static let installedPackages: [InstalledBrewPackage] = [
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
            license: "MIT",
            tap: "homebrew/core",
            installedOnRequest: true,
            pouredFromBottle: true,
            installDate: Date(timeIntervalSinceNow: -86400 * 7),
            linkedKeg: "22.14.0",
        ),
        deprecatedFormula,
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

    static let aiEngine: any AIEngineProtocol = StubAIEngine()
}

public struct StubAIEngine: AIEngineProtocol, Sendable {
    public init() {}
    public func analyzeDoctorIssue(title: String, rawOutput: String) async -> AIAnalysisResult {
        AIAnalysisResult(
            summary: "Sample explanation for preview: \(title)",
            rootCause: "Preview root cause",
            suggestedCommands: ["brew doctor"],
            modelName: "Preview Model"
        )
    }

    public func analyzeCommandFailure(command: String, exitCode: Int, output: String) async -> AIAnalysisResult {
        AIAnalysisResult(
            summary: "Sample failure explanation for preview: \(command)",
            rootCause: "Exit code \(exitCode)",
            suggestedCommands: ["brew update"],
            modelName: "Preview Model"
        )
    }

    public func semanticSearch(query: String, catalogue: [BrewPackage], limit: Int) async -> [AISemanticSearchResult] {
        catalogue.prefix(limit).map {
            AISemanticSearchResult(package: $0, relevanceScore: 0.95, matchReason: "Matches preview query “\(query)”")
        }
    }

    public func assessUpgradeImpact(package: InstalledBrewPackage, targetVersion: String, dependents: [String]) async -> AIUpgradeImpact {
        AIUpgradeImpact(
            packageName: package.name,
            currentVersion: package.installedVersions.first ?? "1.0.0",
            targetVersion: targetVersion,
            riskLevel: dependents.isEmpty ? .low : .medium,
            isMajorVersionBump: true,
            affectedDependents: dependents,
            summary: "Preview impact assessment for \(package.name).",
            breakingChangesWarning: nil,
            serviceRestartNotice: nil,
            recommendedVerificationCommands: ["brew test \(package.name)"]
        )
    }

    public func generateBrewfileEnvironment(prompt: String) async -> AIBrewfileEnvironment {
        AIBrewfileEnvironment(
            title: "Preview Environment",
            prompt: prompt,
            taps: ["homebrew/core"],
            formulae: ["git", "node"],
            casks: ["visual-studio-code"],
            generatedBrewfileContent: "tap \"homebrew/core\"\nbrew \"git\"\nbrew \"node\"\ncask \"visual-studio-code\"",
            bundleCommand: "brew bundle --file=Brewfile",
            explanation: "Curated development environment based on “\(prompt)”."
        )
    }

    public func assessHousekeeping(installedPackages: [InstalledBrewPackage], leaves: [String]) async -> AIHousekeepingReport {
        AIHousekeepingReport(
            orphanCandidates: leaves.prefix(3).compactMap { leaf in
                guard let pkg = installedPackages.first(where: { $0.name == leaf }) else { return nil }
                return AIOrphanCandidate(
                    packageName: pkg.name,
                    installedVersion: pkg.installedVersions.first ?? "1.0",
                    reason: "Top-level formula with no dependents detected",
                    safetyLevel: .safeToPrune
                )
            },
            summary: "Housekeeping analysis preview.",
            recommendedCommands: ["brew autoremove --dry-run", "brew cleanup -s"],
            reclaimableEstimate: "1.2 GB"
        )
    }

    public func suggestAlternatives(for package: BrewPackage) async -> [AIPackageAlternative] {
        [
            AIPackageAlternative(
                name: "ripgrep",
                relationship: "Modern Rust Replacement",
                headline: "Significantly faster search with regex, recursive search, and respect for .gitignore",
                keyAdvantages: ["Up to 10x faster execution", "Automatic .gitignore filtering", "Coloured syntax output"],
                installCommand: "brew install ripgrep"
            )
        ]
    }

    public func recommendPackages(basedOn installedPackages: [InstalledBrewPackage]) async -> [AIPackageRecommendation] {
        [
            AIPackageRecommendation(
                packageName: "bat",
                category: "Modern CLI",
                reason: "Cat clone with syntax highlighting and Git integration",
                confidenceScore: 0.95
            ),
            AIPackageRecommendation(
                packageName: "eza",
                category: "Modern CLI",
                reason: "Modern, feature-rich replacement for ls with tree views",
                confidenceScore: 0.90
            )
        ]
    }

    public func comparePackages(packageA: BrewPackage, packageB: BrewPackage) async -> AIPackageComparison {
        AIPackageComparison(
            packageAName: packageA.displayName,
            packageBName: packageB.displayName,
            verdictSummary: "\(packageB.displayName) is a modern replacement for \(packageA.displayName) with superior performance and user ergonomics.",
            strengthsA: ["Universal availability on POSIX systems", "Zero dependencies", "Standardised scripting behaviour"],
            strengthsB: ["Exceptional speed with multi-threading", "Native Unicode & regex handling", "Intuitive CLI defaults"],
            bestForA: "Legacy shell scripts requiring standard POSIX conformity",
            bestForB: "Interactive daily terminal workflows and large codebases",
            matrix: [
                AIComparisonRow(feature: "Search Performance", packageAValue: "Standard linear scan", packageBValue: "Multi-threaded SIMD accelerated"),
                AIComparisonRow(feature: "Git Integration", packageAValue: "None", packageBValue: "Respects .gitignore by default"),
                AIComparisonRow(feature: "Binary Files", packageAValue: "Scans or skips via flags", packageBValue: "Smart automatic skipping")
            ]
        )
    }
}

@MainActor
public final class StubAIModelManager: AIModelManaging {
    public init() {}
    public var availableModels: [AIModelSpec] { AIModelCatalog.allModels }
    public var activeModelID: String? { AIModelCatalog.qwenCoder15B.id }
    public var hardwareProfile = AISystemHardwareProfile()
    public func downloadState(for model: AIModelSpec) -> AIModelDownloadState { .ready }
    public func setActiveModel(id: String?) {}
    public func startDownload(for model: AIModelSpec) async {}
    public func cancelDownload(for model: AIModelSpec) {}
    public func deleteModel(for model: AIModelSpec) {}
}

