//
//  DoctorReport+Placeholdable.swift
//  BrewCore
//

import Foundation

extension DoctorReport: Placeholdable {
    /// A stub report sized like a real one so the redacted loading skeleton matches the eventual list
    /// layout (a section header + a few rows, one with a "Fix available" hint).
    public static var placeholder: DoctorReport {
        DoctorReport(issues: [
            DoctorIssue(
                title: "Placeholder issue title sized for two lines of redacted text",
                severity: .caution,
                section: .systemAndFormulae,
                blocks: [
                    DoctorBlock(
                        id: 0,
                        caption: nil,
                        content: .command([
                            DoctorFixStep(
                                displayCommand: "brew placeholder",
                                arguments: ["placeholder"],
                                needsAdmin: false,
                            ),
                        ]),
                    ),
                ],
                inlineChips: [],
                rawBody: "",
            ),
            DoctorIssue(
                title: "Second placeholder issue title",
                severity: .caution,
                section: .systemAndFormulae,
                blocks: [],
                inlineChips: [],
                rawBody: "",
            ),
            DoctorIssue(
                title: "Third placeholder issue title",
                severity: .caution,
                section: .systemAndFormulae,
                blocks: [],
                inlineChips: [],
                rawBody: "",
            ),
        ])
    }
}
