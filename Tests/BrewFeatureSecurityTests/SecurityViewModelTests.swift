//
//  SecurityViewModelTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewFeatureSecurity
import BrewRepositoryInterfaces
import Foundation
import Testing

@MainActor
struct SecurityViewModelTests {
    private static func advisory(
        _ id: String,
        severity: AdvisorySeverity,
        fixes: [AdvisoryFix] = [],
    ) -> SecurityAdvisory {
        SecurityAdvisory(id: id, aliases: [], severity: severity, summary: nil, fixes: fixes)
    }

    private static func package(
        _ name: String,
        open: [SecurityAdvisory],
        patched: [SecurityAdvisory] = [],
    ) -> PackageAdvisories {
        PackageAdvisories(
            package: .formula(name: name),
            scannedVersion: "1.0",
            sourceRepository: nil,
            open: open,
            resolvedByPatch: patched,
        )
    }

    private static func viewModel(
        findings: [PackageAdvisories] = [],
        coverage: AdvisoryScanCoverage = AdvisoryScanCoverage(),
    ) -> SecurityViewModel {
        SecurityViewModel(repository: StubSecurityAdvisoryRepository(
            report: SecurityAdvisoryReport(findings: findings, coverage: coverage),
        ))
    }

    // MARK: - Presentation

    @Test func `a report with nothing open is clean`() {
        let viewModel = Self.viewModel(findings: [
            Self.package("curl", open: [], patched: [Self.advisory("CVE-1", severity: .high)]),
        ])

        #expect(viewModel.presentation == .clean)
    }

    @Test func `a report with an open advisory shows findings`() {
        let viewModel = Self.viewModel(findings: [Self.package("curl", open: [Self.advisory("CVE-1", severity: .low)])])

        #expect(viewModel.presentation == .findings)
    }

    @Test func `an unsupported Homebrew is worded for the user`() {
        let viewModel = SecurityViewModel(repository: StubSecurityAdvisoryRepository(
            error: BrewRepositoryError.unsupportedBrewCommand(command: "brew vulns"),
        ))

        #expect(viewModel.presentation == .failed(
            "This version of Homebrew doesn’t support brew vulns. Run brew update to upgrade Homebrew.",
        ))
    }

    @Test func `packages are ordered most severe first`() {
        let viewModel = Self.viewModel(findings: [
            Self.package("low", open: [Self.advisory("A", severity: .low)]),
            Self.package("critical", open: [Self.advisory("B", severity: .critical)]),
            Self.package("medium", open: [Self.advisory("C", severity: .medium)]),
        ])

        #expect(viewModel.items.map(\.name) == ["critical", "medium", "low"])
    }

    @Test func `advisories within a package are ordered most severe first`() {
        let viewModel = Self.viewModel(findings: [
            Self.package("curl", open: [Self.advisory("A", severity: .unknown), Self.advisory("B", severity: .high)]),
        ])

        #expect(viewModel.items.first?.advisories.map(\.id) == ["B", "A"])
    }

    // MARK: - Selection

    @Test func `loading selects the most severe package`() async {
        let viewModel = Self.viewModel(findings: [
            Self.package("low", open: [Self.advisory("A", severity: .low)]),
            Self.package("high", open: [Self.advisory("B", severity: .high)]),
        ])

        await viewModel.load(forceRefresh: false)

        #expect(viewModel.selectedPackageID == .formula(name: "high"))
    }

    @Test func `moving down past the last package stays on it`() async {
        let viewModel = Self.viewModel(findings: [
            Self.package("a", open: [Self.advisory("A", severity: .high)]),
            Self.package("b", open: [Self.advisory("B", severity: .low)]),
        ])
        await viewModel.load(forceRefresh: false)

        viewModel.selectNext()
        viewModel.selectNext()

        #expect(viewModel.selectedPackageID == .formula(name: "b"))
    }

    // MARK: - Coverage

    @Test func `coverage names what was checked and patched`() {
        let viewModel = Self.viewModel(
            findings: [Self.package("curl", open: [], patched: [Self.advisory("CVE-1", severity: .high)])],
            coverage: AdvisoryScanCoverage(checkedCount: 12, skipped: ["a", "b"]),
        )

        #expect(viewModel.coverageSummary
            == "12 formulae checked · 1 advisory already patched by Homebrew · Casks are not scanned")
    }

    @Test func `coverage without a checked count still says casks are not scanned`() {
        let viewModel = Self.viewModel()

        #expect(viewModel.coverageSummary == "Casks are not scanned")
    }

    @Test func `a complete scan has no note`() {
        #expect(Self.viewModel(coverage: AdvisoryScanCoverage(checkedCount: 3)).scanNote == nil)
    }

    @Test func `the note summarises gaps and leaves Homebrew's warnings to the console`() {
        let viewModel = Self.viewModel(coverage: AdvisoryScanCoverage(
            skipped: ["a", "b"],
            outdatedWithoutSBOM: ["zlib", "libpng"],
            unscanned: ["php@7.4": "untrusted_tap"],
            diagnostics: "Warning: 6 installed kegs from an untrusted tap not scanned:\n  …",
        ))

        #expect(viewModel.scanNote == "3 formulae weren’t scanned. "
            + "Results for libpng, zlib reflect the current formula, not the installed version. "
            + "Homebrew reported warnings; see the console for details.")
    }
}

struct SecurityAdvisoryItemTests {
    private static func item(fixes: [AdvisoryFix]) -> SecurityAdvisoryItem {
        SecurityAdvisoryItem(advisory: SecurityAdvisory(id: "CVE-2026-6192", aliases: [], severity: .high, summary: nil, fixes: fixes))
    }

    @Test func `a released fix names its versions`() {
        #expect(Self.item(fixes: [.version("2.5.5"), .version("2.6.0")]).fixDescription == "Fixed upstream in 2.5.5, 2.6.0")
    }

    @Test func `a fix repeated across ranges is listed once`() {
        #expect(Self.item(fixes: [.version("8.23.0"), .version("8.14.3"), .version("8.23.0")]).fixDescription
            == "Fixed upstream in 8.23.0, 8.14.3")
    }

    @Test func `a commit-only fix is never worded as a version`() {
        #expect(Self.item(fixes: [.commit("839936aa33eb8899bbbd80fda02796bb65068951")]).fixDescription
            == "Fixed upstream in a commit that is not yet in a release")
    }

    @Test func `no recorded fix says so`() {
        #expect(Self.item(fixes: []).fixDescription == "No upstream fix is known yet")
    }

    @Test func `the advisory links to its OSV record`() {
        #expect(Self.item(fixes: []).advisoryURL == URL(string: "https://osv.dev/vulnerability/CVE-2026-6192"))
    }
}
