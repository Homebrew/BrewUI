//
//  VulnsJSONParserTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewRepositories
import Foundation
import Testing

/// Fixtures follow a real `brew vulns --json --max-summary=0` run (Homebrew 7.0.9), plus the extra
/// coverage keys later Homebrew versions add.
struct VulnsJSONParserTests {
    private static func parse(_ json: String, diagnostics: String = "") throws -> SecurityAdvisoryReport {
        try VulnsJSONParser.parse(Data(json.utf8), diagnostics: diagnostics)
    }

    private static let homebrew709 = """
    {
      "findings": [
        {
          "formula": "openjpeg",
          "version": "2.5.4",
          "tag": "v2.5.4",
          "repo_url": "https://github.com/uclouvain/openjpeg",
          "vulnerabilities": [
            {
              "id": "CVE-2026-6192",
              "severity": "UNKNOWN",
              "summary": "uclouvain openjpeg pi.c opj_pi_initialise_encode integer overflow",
              "aliases": [],
              "fixed_versions": ["839936aa33eb8899bbbd80fda02796bb65068951"]
            },
            {
              "id": "OSV-2025-219",
              "severity": "HIGH",
              "summary": "Heap-buffer-overflow in opj_j2k_read_tile_header",
              "aliases": [],
              "fixed_versions": ["2.5.5"]
            }
          ],
          "patched": []
        }
      ],
      "skipped_formulae": ["some-formula"]
    }
    """

    @Test func `each finding becomes one package with its open advisories`() throws {
        let report = try Self.parse(Self.homebrew709)

        #expect(report.findings.map(\.package) == [.formula(name: "openjpeg")])
        #expect(report.findings.first?.open.map(\.id) == ["CVE-2026-6192", "OSV-2025-219"])
    }

    @Test func `the scanned version and source repository are kept`() throws {
        let package = try #require(try Self.parse(Self.homebrew709).findings.first)

        #expect(package.scannedVersion == "2.5.4")
        #expect(package.sourceRepository == URL(string: "https://github.com/uclouvain/openjpeg"))
    }

    @Test func `a 40-character hex fix is a commit, not a version`() throws {
        let package = try #require(try Self.parse(Self.homebrew709).findings.first)

        #expect(package.open.map(\.fixes) == [
            [.commit("839936aa33eb8899bbbd80fda02796bb65068951")],
            [.version("2.5.5")],
        ])
    }

    @Test func `severity strings map to ordered levels`() {
        let mapped = ["CRITICAL", "HIGH", "MEDIUM", "LOW", "UNKNOWN", "SOMETHING-NEW"].map(VulnsJSONParser.severity(from:))

        #expect(mapped == [.critical, .high, .medium, .low, .unknown, .unknown])
    }

    @Test func `the highest open severity ranks the package`() throws {
        let package = try #require(try Self.parse(Self.homebrew709).findings.first)

        #expect(package.highestSeverity == .high)
    }

    @Test func `version 7_0_9 output has no checked count`() throws {
        let coverage = try Self.parse(Self.homebrew709).coverage

        #expect(coverage == AdvisoryScanCoverage(checkedCount: nil, skipped: ["some-formula"]))
    }

    @Test func `newer coverage keys are read when present`() throws {
        let report = try Self.parse("""
        {
          "findings": [],
          "skipped_formulae": [],
          "checked": 12,
          "complete": false,
          "outdated_without_sbom": ["libpng"],
          "unscanned_formulae": {"php@7.4": "untrusted_tap"}
        }
        """)

        #expect(report.coverage == AdvisoryScanCoverage(
            checkedCount: 12,
            outdatedWithoutSBOM: ["libpng"],
            unscanned: ["php@7.4": "untrusted_tap"],
        ))
    }

    @Test func `patched advisories are kept apart from open ones`() throws {
        let report = try Self.parse("""
        {"findings": [{"formula": "curl", "version": "8.15.0", "tag": "curl-8_15_0", "repo_url": null,
          "vulnerabilities": [],
          "patched": [{"id": "CVE-2025-9086", "severity": "MEDIUM", "summary": null, "aliases": [], "fixed_versions": []}]}],
         "skipped_formulae": []}
        """)

        #expect(report.findings.first?.resolvedByPatch.map(\.id) == ["CVE-2025-9086"])
    }

    @Test func `a formula with only patched advisories is not affected`() throws {
        let report = try Self.parse("""
        {"findings": [{"formula": "curl", "version": "8.15.0", "tag": "t", "repo_url": null,
          "vulnerabilities": [],
          "patched": [{"id": "CVE-2025-9086", "severity": "MEDIUM", "summary": null, "aliases": [], "fixed_versions": []}]}],
         "skipped_formulae": []}
        """)

        #expect(report.affectedPackages.isEmpty)
    }

    @Test func `an empty summary becomes nil`() throws {
        let report = try Self.parse("""
        {"findings": [{"formula": "a", "version": "1", "tag": "1", "repo_url": null,
          "vulnerabilities": [{"id": "X-1", "severity": "LOW", "summary": "  ", "aliases": [], "fixed_versions": []}],
          "patched": []}],
         "skipped_formulae": []}
        """)

        #expect(report.findings.first?.open.first?.summary == nil)
    }

    @Test func `diagnostics are carried into coverage`() throws {
        let coverage = try Self.parse(Self.homebrew709, diagnostics: "Warning: untrusted").coverage

        #expect(coverage.diagnostics == "Warning: untrusted")
    }

    @Test func `output that is not JSON throws`() {
        #expect(throws: DecodingError.self) {
            try Self.parse("Checking 3 packages for vulnerabilities...")
        }
    }
}
