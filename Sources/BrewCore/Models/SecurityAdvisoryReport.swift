//
//  SecurityAdvisoryReport.swift
//  BrewCore
//

import Foundation

/// Outcome of a `brew vulns` scan of the installed formulae.
///
/// Actor-neutral domain value (no presentation). `brew vulns` checks formulae only, so casks never
/// appear here, and an empty ``findings`` list means no *known* advisory matched rather than a
/// guarantee that none exists.
public struct SecurityAdvisoryReport: Equatable, Sendable {
    /// Formulae with at least one open advisory or one resolved by a formula patch.
    public var findings: [PackageAdvisories]
    public var coverage: AdvisoryScanCoverage

    public init(findings: [PackageAdvisories], coverage: AdvisoryScanCoverage) {
        self.findings = findings
        self.coverage = coverage
    }

    /// Formulae with at least one advisory that is still open, most severe first.
    public var affectedPackages: [PackageAdvisories] {
        findings
            .filter { !$0.open.isEmpty }
            .sorted { lhs, rhs in
                if lhs.highestSeverity != rhs.highestSeverity {
                    return lhs.highestSeverity > rhs.highestSeverity
                }
                return lhs.package.name < rhs.package.name
            }
    }

    /// Total advisories Homebrew has already resolved with a formula patch.
    public var resolvedByPatchCount: Int {
        findings.reduce(0) { $0 + $1.resolvedByPatch.count }
    }
}

/// Advisories `brew vulns` matched against one installed formula.
public struct PackageAdvisories: Identifiable, Equatable, Sendable {
    public var package: HomebrewPackageID
    /// The version `brew vulns` matched against, which is the installed one when an SBOM exists.
    public var scannedVersion: String
    /// The upstream repository `brew vulns` queried OSV with, when it reported one.
    public var sourceRepository: URL?
    /// Advisories that still apply.
    public var open: [SecurityAdvisory]
    /// Advisories that match the upstream version but that a Homebrew formula patch already fixes.
    public var resolvedByPatch: [SecurityAdvisory]

    public init(
        package: HomebrewPackageID,
        scannedVersion: String,
        sourceRepository: URL?,
        open: [SecurityAdvisory],
        resolvedByPatch: [SecurityAdvisory],
    ) {
        self.package = package
        self.scannedVersion = scannedVersion
        self.sourceRepository = sourceRepository
        self.open = open
        self.resolvedByPatch = resolvedByPatch
    }

    public var id: HomebrewPackageID {
        package
    }

    /// The most severe open advisory's severity; ``AdvisorySeverity/unknown`` when nothing is open.
    public var highestSeverity: AdvisorySeverity {
        open.map(\.severity).max() ?? .unknown
    }
}

/// One OSV advisory, as `brew vulns` reported it.
public struct SecurityAdvisory: Identifiable, Equatable, Sendable {
    /// OSV identifier, e.g. `CVE-2026-6192`, `GHSA-…` or `OSV-2025-219`.
    public var id: String
    /// Other identifiers for the same advisory.
    public var aliases: [String]
    public var severity: AdvisorySeverity
    public var summary: String?
    public var fixes: [AdvisoryFix]

    public init(
        id: String,
        aliases: [String],
        severity: AdvisorySeverity,
        summary: String?,
        fixes: [AdvisoryFix],
    ) {
        self.id = id
        self.aliases = aliases
        self.severity = severity
        self.summary = summary
        self.fixes = fixes
    }
}

/// Ordered so `max()` picks the most severe; ``unknown`` ranks lowest because OSV gave no score.
public enum AdvisorySeverity: Int, Comparable, Sendable {
    case unknown
    case low
    case medium
    case high
    case critical

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Where an advisory is fixed upstream. OSV ranges can end at a release or only at a commit.
public enum AdvisoryFix: Equatable, Sendable {
    case version(String)
    /// Fixed by an upstream commit that may not be in any release yet.
    case commit(String)
}

/// What a scan did and did not look at, so the app never presents a partial scan as a clean one.
public struct AdvisoryScanCoverage: Equatable, Sendable {
    /// Formulae queried, when `brew vulns` reports it (Homebrew after 7.0.9).
    public var checkedCount: Int?
    /// Formulae with no supported source URL to query.
    public var skipped: [String]
    /// Formulae whose installed source is unknown, so the current formula version was checked instead.
    public var outdatedWithoutSBOM: [String]
    /// Formulae Homebrew refused to load, keyed by name, with its reason.
    public var unscanned: [String: String]
    /// `brew vulns` warnings, such as untrusted-tap kegs it did not scan, kept verbatim.
    public var diagnostics: String

    public init(
        checkedCount: Int? = nil,
        skipped: [String] = [],
        outdatedWithoutSBOM: [String] = [],
        unscanned: [String: String] = [:],
        diagnostics: String = "",
    ) {
        self.checkedCount = checkedCount
        self.skipped = skipped
        self.outdatedWithoutSBOM = outdatedWithoutSBOM
        self.unscanned = unscanned
        self.diagnostics = diagnostics
    }
}
