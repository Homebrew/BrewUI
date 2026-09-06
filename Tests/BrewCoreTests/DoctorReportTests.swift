//
//  DoctorReportTests.swift
//  BrewTests
//

@testable import BrewCore
import Testing

struct DoctorReportTests {
    private static func issue(
        title: String = "Some installed casks are deprecated or disabled.",
        titlePrefix: String = "Warning:",
        rawBody: String = "",
    ) -> DoctorIssue {
        DoctorIssue(title: title, titlePrefix: titlePrefix, severity: .caution, blocks: [], rawBody: rawBody)
    }

    @Test func `rawText puts the summary line back the way brew printed it`() {
        let issue = Self.issue(rawBody: "You should find replacements for the following casks:\nrar")

        #expect(issue.rawText == """
        Warning: Some installed casks are deprecated or disabled.
        You should find replacements for the following casks:
        rar
        """)
    }

    @Test func `a title-only finding still shows its summary line`() {
        #expect(Self.issue(title: "Your Command Line Tools are too outdated.").rawText
            == "Warning: Your Command Line Tools are too outdated.")
    }

    /// `Error:` findings come from brew's `ofail` path; quoting one as a warning would misreport it.
    @Test func `an error finding keeps brew's own prefix`() {
        #expect(Self.issue(title: "No check available.", titlePrefix: "Error:").rawText
            == "Error: No check available.")
    }
}
