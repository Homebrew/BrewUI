//
//  SecurityAdvisoryReport+Placeholdable.swift
//  BrewCore
//

import Foundation

extension SecurityAdvisoryReport: Placeholdable {
    /// Sized like a small real report so the redacted loading skeleton matches the eventual list.
    public static var placeholder: SecurityAdvisoryReport {
        let advisory = SecurityAdvisory(
            id: "CVE-0000-00000",
            aliases: [],
            severity: .high,
            summary: "Placeholder advisory summary sized for one line",
            fixes: [.version("0.0.0")],
        )
        return SecurityAdvisoryReport(
            findings: ["placeholder-one", "placeholder-two", "placeholder-three"].map { name in
                PackageAdvisories(
                    package: .formula(name: name),
                    scannedVersion: "0.0.0",
                    sourceRepository: nil,
                    open: [advisory],
                    resolvedByPatch: [],
                )
            },
            coverage: AdvisoryScanCoverage(checkedCount: 0),
        )
    }
}
