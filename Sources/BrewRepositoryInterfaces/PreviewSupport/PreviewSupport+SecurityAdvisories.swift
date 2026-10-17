//
//  PreviewSupport+SecurityAdvisories.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

public extension PreviewSupport {
    @MainActor
    static func makeSecurityAdvisoryRepository(
        report: SecurityAdvisoryReport = securityAdvisoryReport,
    ) -> any SecurityAdvisoryRepository {
        StubSecurityAdvisoryRepository(report: report, scannedAt: Date(timeIntervalSinceNow: -600))
    }

    static let cleanSecurityAdvisoryReport = SecurityAdvisoryReport(
        findings: [],
        coverage: AdvisoryScanCoverage(checkedCount: 42),
    )

    /// Shaped like a real `brew vulns` run: a released fix, an unreleased commit fix, no score, and a
    /// patched advisory alongside an untrusted-tap warning.
    static let securityAdvisoryReport = SecurityAdvisoryReport(
        findings: [
            PackageAdvisories(
                package: .formula(name: "openjpeg"),
                scannedVersion: "2.5.4",
                sourceRepository: URL(string: "https://github.com/uclouvain/openjpeg"),
                open: [
                    SecurityAdvisory(
                        id: "OSV-2025-219",
                        aliases: [],
                        severity: .high,
                        summary: "Heap-buffer-overflow in opj_j2k_read_tile_header",
                        fixes: [.commit("d33cbecc148d3affcdf403211fddc2cc5d442379")],
                    ),
                    SecurityAdvisory(
                        id: "CVE-2026-6192",
                        aliases: [],
                        severity: .unknown,
                        summary: "uclouvain openjpeg pi.c opj_pi_initialise_encode integer overflow",
                        fixes: [],
                    ),
                ],
                resolvedByPatch: [],
            ),
            PackageAdvisories(
                package: .formula(name: "curl"),
                scannedVersion: "8.15.0",
                sourceRepository: URL(string: "https://github.com/curl/curl"),
                open: [
                    SecurityAdvisory(
                        id: "CVE-2026-1001",
                        aliases: ["GHSA-abcd-1234-efgh"],
                        severity: .critical,
                        summary: "Use after free in connection reuse",
                        fixes: [.version("8.16.0")],
                    ),
                ],
                resolvedByPatch: [
                    SecurityAdvisory(id: "CVE-2025-9086", aliases: [], severity: .medium, summary: nil, fixes: []),
                ],
            ),
        ],
        coverage: AdvisoryScanCoverage(
            checkedCount: 42,
            skipped: ["sample-skipped"],
            diagnostics: "Warning: 1 installed keg from an untrusted tap not scanned:\n  example/tap/tool",
        ),
    )
}
