//
//  ScenarioFixtures.swift
//  BrewUITests
//

import Foundation

/// `brewFiles` are keyed as ``FakeBrew`` looks them up, argv joined with `_` plus a role suffix;
/// `httpFiles` by request path with `/` replaced by `_`.
struct FixtureSet {
    var brewFiles: [String: Data] = [:]
    var httpFiles: [String: Data] = [:]
}

/// The fixture sets behind ``BrewUITestScenario``. Every scenario answers the whole read-only command
/// surface, because a missing fixture exits 64 and surfaces as an unrelated error state.
enum ScenarioFixtures {
    /// Both a fixture file name and the key a mutating command rewrites, so it is spelled once.
    static let installedInfoKey = "info_--installed_--json=v2"

    static func fixtures(for scenario: BrewUITestScenario) -> FixtureSet {
        switch scenario {
        case .empty, .brewNotFound:
            emptyFixtures()
        case .installedBasic:
            installedBasicFixtures()
        case .installedLarge:
            installedLargeFixtures()
        case .doctorHasIssues:
            doctorHasIssuesFixtures()
        case .discoverSearch:
            discoverSearchFixtures()
        case .catalogueServerError:
            catalogueServerErrorFixtures()
        case .malformedInstalledInfo:
            malformedInstalledInfoFixtures()
        case .installFailure:
            installFailureFixtures()
        }
    }

    // MARK: - Packages

    static let wget = FixturePackage(
        token: "wget",
        kind: .formula,
        summary: "Internet file retriever",
        installedVersion: "1.25.0",
        latestVersion: "1.25.0",
    )

    static let ripgrep = FixturePackage(
        token: "ripgrep",
        kind: .formula,
        summary: "Search tool like grep and The Silver Searcher",
        installedVersion: "14.1.0",
        latestVersion: "14.1.1",
    )

    static let iterm2 = FixturePackage(
        token: "iterm2",
        kind: .cask,
        displayName: "iTerm2",
        summary: "Terminal emulator as alternative to Apple's Terminal app",
        installedVersion: "3.5.0",
        latestVersion: "3.5.0",
    )

    static let rectangle = FixturePackage(
        token: "rectangle",
        kind: .cask,
        displayName: "Rectangle",
        summary: "Move and resize windows using keyboard shortcuts or snap areas",
        installedVersion: "0.84",
        latestVersion: "0.90",
    )

    /// Catalogue-only packages — present in `formula.json` / `cask.json`, never installed.
    static let fd = FixturePackage(
        token: "fd",
        kind: .formula,
        summary: "Simple, fast and user-friendly alternative to find",
        latestVersion: "10.2.0",
    )

    static let uninstalledRipgrep = FixturePackage(
        token: "ripgrep",
        kind: .formula,
        summary: "Search tool like grep and The Silver Searcher",
        latestVersion: "14.1.1",
    )

    // MARK: - Scenarios

    private static func emptyFixtures() -> FixtureSet {
        var set = FixtureSet()
        set.brewFiles = baseBrewFiles(installed: [])
        set.httpFiles = catalogueFiles(packages: [])
            .merging(analyticsFiles(formulae: [], casks: []), uniquingKeysWith: { first, _ in first })
        return set
    }

    private static func installedBasicFixtures() -> FixtureSet {
        let installed = [wget, ripgrep, iterm2, rectangle]
        var set = FixtureSet()
        set.brewFiles = baseBrewFiles(installed: installed)

        // The next `brew info` has to report a world without wget, or the row never goes.
        let remaining = installed.filter { $0.token != wget.token }
        set.brewFiles["uninstall_--formula_wget.stdout"] = text(
            """
            ==> Uninstalling wget
            Uninstalling /opt/homebrew/Cellar/wget/1.25.0... (91 files, 4.1MB)
            """,
        )
        set.brewFiles["uninstall_--formula_wget.next-info"] = infoJSON(for: remaining)

        set.httpFiles = catalogueFiles(packages: installed)
            .merging(analyticsFiles(formulae: [], casks: []), uniquingKeysWith: { first, _ in first })
        return set
    }

    private static func installedLargeFixtures() -> FixtureSet {
        // Far more than one pipe buffer: reading only after `waitUntilExit` would deadlock here.
        let installed = (0 ..< 400).map { index in
            FixturePackage(
                token: String(format: "bulk-formula-%03d", index),
                kind: .formula,
                summary: "Bulk fixture package \(index) — padding to force a multi-buffer stdout drain",
                installedVersion: "1.0.\(index)",
                latestVersion: "1.0.\(index)",
            )
        }
        var set = FixtureSet()
        set.brewFiles = baseBrewFiles(installed: installed)
        set.httpFiles = catalogueFiles(packages: [])
            .merging(analyticsFiles(formulae: [], casks: []), uniquingKeysWith: { first, _ in first })
        return set
    }

    private static func doctorHasIssuesFixtures() -> FixtureSet {
        var set = emptyFixtures()
        set.brewFiles["doctor.stdout"] = text(
            """
            Warning: Some installed formulae are deprecated or disabled.
            You should find replacements for the following formulae:
              openssl@1.1

            Warning: You have unlinked kegs in your Cellar.
            Leaving kegs unlinked can lead to build-trouble and cause formulae that depend on
            those kegs to fail to run properly once built.
              openssl@3
            """,
        )
        // `brew doctor` exits non-zero when it finds anything, so the fixture reproduces that.
        set.brewFiles["doctor.exitcode"] = text("1")
        set.brewFiles["doctor_--json.stdout"] = json([
            "tier": 1,
            "findings": [
                [
                    "text": "Some installed formulae are deprecated or disabled.",
                    "tier": 1,
                    "affects": ["openssl@1.1"],
                    "links": [],
                    "remediation": [
                        "commands": [],
                        "text": "You should find replacements for the following formulae:\n  openssl@1.1\n",
                    ],
                ],
                [
                    "text": "You have unlinked kegs in your Cellar.",
                    "tier": 1,
                    "affects": ["openssl@3"],
                    "links": [],
                    "remediation": [
                        "commands": ["brew link openssl@3"],
                        "text": """
                        Leaving kegs unlinked can lead to build-trouble and cause formulae that depend on
                        those kegs to fail to run properly once built.
                          openssl@3
                        """,
                    ],
                ],
            ],
        ])
        set.brewFiles["doctor_--json.exitcode"] = text("1")
        return set
    }

    private static func discoverSearchFixtures() -> FixtureSet {
        let catalogue = [uninstalledRipgrep, fd, iterm2]
        var set = FixtureSet()
        set.brewFiles = baseBrewFiles(installed: [])
        set.brewFiles["install_--formula_ripgrep.stdout"] = text(
            """
            ==> Fetching ripgrep
            ==> Downloading https://ghcr.io/v2/homebrew/core/ripgrep/blobs/sha256:deadbeef
            ==> Pouring ripgrep--14.1.1.arm64_sequoia.bottle.tar.gz
            🍺  /opt/homebrew/Cellar/ripgrep/14.1.1: 13 files, 5.4MB
            """,
        )
        set.brewFiles["install_--formula_ripgrep.next-info"] = infoJSON(for: [
            FixturePackage(
                token: "ripgrep",
                kind: .formula,
                summary: uninstalledRipgrep.summary,
                installedVersion: "14.1.1",
                latestVersion: "14.1.1",
            ),
        ])

        set.httpFiles = catalogueFiles(packages: catalogue)
            .merging(
                analyticsFiles(formulae: [(fd, 9000)], casks: [(iterm2, 4000)]),
                uniquingKeysWith: { first, _ in first },
            )
        return set
    }

    private static func catalogueServerErrorFixtures() -> FixtureSet {
        var set = FixtureSet()
        set.brewFiles = baseBrewFiles(installed: [])
        // Trending must reach the catalogue for the 500 to matter, so analytics names a formula to enrich.
        set.httpFiles = analyticsFiles(formulae: [(fd, 9000)], casks: [])
        set.httpFiles["api_formula.json"] = text("upstream is having a bad day")
        set.httpFiles["api_formula.json.status"] = text("500")
        set.httpFiles["api_cask.json"] = json([])
        return set
    }

    private static func malformedInstalledInfoFixtures() -> FixtureSet {
        var set = emptyFixtures()
        // Exit 0 with a non-JSON body, so the failure comes from the decode step rather than the exit code.
        set.brewFiles["\(installedInfoKey).stdout"] = text("<html><body>502 Bad Gateway</body></html>")
        return set
    }

    private static func installFailureFixtures() -> FixtureSet {
        var set = discoverSearchFixtures()
        set.brewFiles["install_--formula_ripgrep.stdout"] = text("==> Fetching ripgrep")
        set.brewFiles["install_--formula_ripgrep.stderr"] = text(
            """
            Error: Failure while executing; `git clone` exited with 128.
            """,
        )
        set.brewFiles["install_--formula_ripgrep.exitcode"] = text("1")
        // A failed install must not change the world.
        set.brewFiles["install_--formula_ripgrep.next-info"] = nil
        return set
    }

    // MARK: - Builders

    /// The read-only commands every scenario must answer.
    private static func baseBrewFiles(installed: [FixturePackage]) -> [String: Data] {
        [
            "\(installedInfoKey).stdout": infoJSON(for: installed),
            "config.stdout": configOutput,
            "doctor.stdout": text("Your system is ready to brew.\n"),
            "doctor_--json.stdout": json(["tier": 1, "findings": []]),
        ]
    }

    private static func infoJSON(for packages: [FixturePackage]) -> Data {
        json([
            "formulae": packages.filter { $0.kind == .formula }.map(\.infoFormulaJSON),
            "casks": packages.filter { $0.kind == .cask }.map(\.infoCaskJSON),
        ])
    }

    private static func catalogueFiles(packages: [FixturePackage]) -> [String: Data] {
        [
            "api_formula.json": json(packages.filter { $0.kind == .formula }.map(\.catalogueFormulaJSON)),
            "api_cask.json": json(packages.filter { $0.kind == .cask }.map(\.catalogueCaskJSON)),
            // A stable ETag, so a second launch in the same run takes the client's 304 path.
            "api_formula.json.etag": text("\"formula-fixture\""),
            "api_cask.json.etag": text("\"cask-fixture\""),
        ]
    }

    /// `rankedPackageCounts()` reads `formulae ?? casks`, so the cask response must **omit** the
    /// `formulae` key: an empty-but-present bucket wins the `??` and the casks go unread.
    private static func analyticsFiles(
        formulae: [(FixturePackage, Int)],
        casks: [(FixturePackage, Int)],
    ) -> [String: Data] {
        var formulaBody: [String: Any] = analyticsEnvelope(category: "install_on_request", entries: formulae)
        formulaBody["formulae"] = Dictionary(uniqueKeysWithValues: formulae.map { package, count in
            (package.token, [["formula": package.token, "count": String(count)]])
        })

        var caskBody: [String: Any] = analyticsEnvelope(category: "cask_install", entries: casks)
        caskBody["casks"] = Dictionary(uniqueKeysWithValues: casks.map { package, count in
            (package.token, [["cask": package.token, "count": String(count)]])
        })

        return [
            "api_analytics_install-on-request_homebrew-core_30d.json": json(formulaBody),
            "api_analytics_cask-install_homebrew-cask_30d.json": json(caskBody),
        ]
    }

    private static func analyticsEnvelope(
        category: String,
        entries: [(FixturePackage, Int)],
    ) -> [String: Any] {
        [
            "category": category,
            "total_items": entries.count,
            "total_count": entries.reduce(0) { $0 + $1.1 },
            "start_date": "2026-01-01",
            "end_date": "2026-01-31",
        ]
    }

    private static let configOutput = text(
        """
        HOMEBREW_VERSION: 4.4.0
        ORIGIN: https://github.com/Homebrew/brew
        HEAD: 0123456789abcdef0123456789abcdef01234567
        Last commit: 3 days ago
        Core tap JSON: 01 Jan 00:00 UTC
        HOMEBREW_PREFIX: /opt/homebrew
        HOMEBREW_CASK_OPTS: []
        Clang: 16.0.0 build 1600
        Git: 2.47.0 => /opt/homebrew/bin/git
        macOS: 26.0-arm64
        CLT: 16.0.0.0.1
        Xcode: 16.0
        """,
    )

    private static func text(_ value: String) -> Data {
        Data(value.utf8)
    }

    /// Serialised rather than hand-written, so invalid JSON fails here rather than inside the app.
    private static func json(_ object: Any) -> Data {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            preconditionFailure("Fixture is not JSON-serialisable: \(object)")
        }
        return data
    }
}
