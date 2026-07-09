//
//  CrashReportTests.swift
//  BrewTests
//

@testable import BrewCrashReporting
import Foundation
import Testing

struct CrashReportTests {
    @Test func `summary is the first content line, skipping separators`() {
        let report = CrashReport(
            id: "crash-1.log",
            capturedAt: Date(timeIntervalSince1970: 0),
            text: """
            Homebrew.app crash report
            =========================

            Signal: SIGSEGV
            """,
        )

        #expect(report.summary == "Homebrew.app crash report")
    }

    @Test func `summary falls back when there is no content`() {
        let report = CrashReport(id: "crash-1.log", capturedAt: Date(), text: "\n===\n")

        #expect(report.summary == "Unexpected crash")
    }
}
