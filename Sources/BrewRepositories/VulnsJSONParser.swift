//
//  VulnsJSONParser.swift
//  BrewRepositories
//

import BrewCore
import Foundation

/// Decodes `brew vulns --json` into a ``SecurityAdvisoryReport``.
///
/// Homebrew 7.0.9 emits `findings` and `skipped_formulae`; later versions add `checked`,
/// `outdated_without_sbom` and `unscanned_formulae`, so those are optional. Unknown keys are ignored.
enum VulnsJSONParser {
    static func parse(_ data: Data, diagnostics: String = "") throws -> SecurityAdvisoryReport {
        let payload = try JSONDecoder().decode(VulnsJSON.self, from: data)
        return SecurityAdvisoryReport(
            findings: payload.findings.map(PackageAdvisories.init(finding:)),
            coverage: AdvisoryScanCoverage(
                checkedCount: payload.checked,
                skipped: payload.skippedFormulae ?? [],
                outdatedWithoutSBOM: payload.outdatedWithoutSBOM ?? [],
                unscanned: payload.unscannedFormulae ?? [:],
                diagnostics: diagnostics,
            ),
        )
    }

    /// OSV's `fixed` event holds either a release version or, for `GIT` ranges, a full commit hash.
    static func fix(from value: String) -> AdvisoryFix {
        let isCommitHash = value.count == 40 && value.allSatisfy(\.isHexDigit)
        return isCommitHash ? .commit(value) : .version(value)
    }

    static func severity(from value: String?) -> AdvisorySeverity {
        switch value?.uppercased() {
        case "CRITICAL": .critical
        case "HIGH": .high
        case "MEDIUM", "MODERATE": .medium
        case "LOW": .low
        default: .unknown
        }
    }
}

private struct VulnsJSON: Decodable {
    let findings: [VulnsFindingJSON]
    let skippedFormulae: [String]?
    let checked: Int?
    let outdatedWithoutSBOM: [String]?
    let unscannedFormulae: [String: String]?

    enum CodingKeys: String, CodingKey {
        case findings
        case skippedFormulae = "skipped_formulae"
        case checked
        case outdatedWithoutSBOM = "outdated_without_sbom"
        case unscannedFormulae = "unscanned_formulae"
    }
}

private struct VulnsFindingJSON: Decodable {
    let formula: String
    let version: String
    let repoURL: String?
    let vulnerabilities: [VulnsVulnerabilityJSON]
    let patched: [VulnsVulnerabilityJSON]?

    enum CodingKeys: String, CodingKey {
        case formula
        case version
        case repoURL = "repo_url"
        case vulnerabilities
        case patched
    }
}

private struct VulnsVulnerabilityJSON: Decodable {
    let id: String
    let severity: String?
    let summary: String?
    let aliases: [String]?
    let fixedVersions: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case severity
        case summary
        case aliases
        case fixedVersions = "fixed_versions"
    }
}

private extension PackageAdvisories {
    init(finding: VulnsFindingJSON) {
        self.init(
            package: .formula(name: finding.formula),
            scannedVersion: finding.version,
            sourceRepository: finding.repoURL.flatMap(URL.init(string:)),
            open: finding.vulnerabilities.map(SecurityAdvisory.init(vulnerability:)),
            resolvedByPatch: (finding.patched ?? []).map(SecurityAdvisory.init(vulnerability:)),
        )
    }
}

private extension SecurityAdvisory {
    init(vulnerability: VulnsVulnerabilityJSON) {
        let summary = vulnerability.summary?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(
            id: vulnerability.id,
            aliases: vulnerability.aliases ?? [],
            severity: VulnsJSONParser.severity(from: vulnerability.severity),
            summary: summary?.isEmpty == false ? summary : nil,
            fixes: (vulnerability.fixedVersions ?? []).map(VulnsJSONParser.fix(from:)),
        )
    }
}
