//
//  SecurityPackageItem.swift
//  BrewFeatureSecurity
//

import BrewCore
import Foundation

/// Presentation mapping for one formula with open advisories, shared by its list row and detail pane.
struct SecurityPackageItem: Identifiable, Equatable {
    let id: HomebrewPackageID
    let name: String
    let scannedVersion: String
    let highestSeverity: AdvisorySeverity
    let advisories: [SecurityAdvisoryItem]
    let resolvedByPatchIDs: [String]
    let sourceRepository: URL?

    init(package: PackageAdvisories) {
        id = package.package
        name = package.package.name
        scannedVersion = package.scannedVersion
        highestSeverity = package.highestSeverity
        advisories = package.open
            .sorted { $0.severity > $1.severity }
            .map(SecurityAdvisoryItem.init(advisory:))
        resolvedByPatchIDs = package.resolvedByPatch.map(\.id)
        sourceRepository = package.sourceRepository
    }

    var advisoryCountText: String {
        advisories.count == 1
            ? String(localized: "1 advisory", bundle: #bundle, comment: "Security row: count of open advisories for one package")
            : String(localized: "\(advisories.count) advisories", bundle: #bundle, comment: "Security row: count of open advisories; %lld is the count")
    }

    /// The scanned version is brew's own string, so only the framing is localised.
    var versionText: String {
        String(localized: "Scanned version \(scannedVersion)", bundle: #bundle, comment: "Security detail: the version brew vulns checked; %@ is the version")
    }

    var accessibilityLabel: String {
        String(
            localized: "\(name), \(advisoryCountText), highest severity \(AdvisorySeverityStyle.displayName(highestSeverity))",
            bundle: #bundle,
            comment: "VoiceOver: Security row; %1$@ is the package, %2$@ the advisory count, %3$@ the severity",
        )
    }
}

/// Presentation mapping for one open advisory.
struct SecurityAdvisoryItem: Identifiable, Equatable {
    let id: String
    let severity: AdvisorySeverity
    let summary: String?
    let aliases: [String]
    let fixedVersions: [String]
    let fixCommits: [String]

    init(advisory: SecurityAdvisory) {
        id = advisory.id
        severity = advisory.severity
        summary = advisory.summary
        aliases = advisory.aliases
        // OSV repeats a fix once per affected range, so the same release often appears several times.
        fixedVersions = Self.uniqued(advisory.fixes.compactMap { fix in
            if case let .version(version) = fix { version } else { nil }
        })
        fixCommits = Self.uniqued(advisory.fixes.compactMap { fix in
            if case let .commit(commit) = fix { commit } else { nil }
        })
    }

    private static func uniqued(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    /// OSV resolves CVE, GHSA and OSV identifiers alike under one path.
    var advisoryURL: URL? {
        guard let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return URL(string: "https://osv.dev/vulnerability/\(encoded)")
    }

    /// A commit hash is not something the user can upgrade to, so it is never worded as a version.
    var fixDescription: String {
        if !fixedVersions.isEmpty {
            let versions = fixedVersions.joined(separator: ", ")
            return String(localized: "Fixed upstream in \(versions)", bundle: #bundle, comment: "Security advisory: released fix; %@ is one or more version numbers")
        }
        if !fixCommits.isEmpty {
            return String(
                localized: "Fixed upstream in a commit that is not yet in a release",
                bundle: #bundle,
                comment: "Security advisory: fix exists only as an unreleased commit",
            )
        }
        return String(localized: "No upstream fix is known yet", bundle: #bundle, comment: "Security advisory: no fix recorded")
    }

    var hasReleasedFix: Bool {
        !fixedVersions.isEmpty
    }

    /// Short commit hashes, as `git log --oneline` would show them.
    var shortFixCommits: [String] {
        fixCommits.map { String($0.prefix(12)) }
    }
}
