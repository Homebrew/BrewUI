//
//  CrashReportFormatterTests.swift
//  BrewTests
//

@testable import BrewCrashReporting
import Foundation
import Testing

private let sampleEnvironment = CrashReportEnvironment(
    appVersion: "1.2.3",
    buildNumber: "45",
    osVersion: "Version 26.0 (Build 26A1)",
)

struct CrashReportFormatterTests {
    @Test func `signal header includes version, os, and a call-stack marker`() {
        let header = CrashReportFormatter.signalReportHeader(
            environment: sampleEnvironment,
            date: Date(timeIntervalSince1970: 0),
        )

        #expect(header.contains("App version: 1.2.3 (45)"))
        #expect(header.contains("macOS: Version 26.0 (Build 26A1)"))
        #expect(header.hasSuffix("Call stack:\n"))
    }

    @Test func `exception report joins the call stack and includes the reason`() {
        let text = CrashReportFormatter.makeReportText(
            kind: "Uncaught exception NSRangeException",
            detail: "index out of bounds",
            callStack: ["0 frame-a", "1 frame-b"],
            environment: sampleEnvironment,
            date: Date(timeIntervalSince1970: 0),
        )

        #expect(text.contains("Type: Uncaught exception NSRangeException"))
        #expect(text.contains("Reason: index out of bounds"))
        #expect(text.contains("0 frame-a\n1 frame-b"))
    }

    @Test func `exception report omits the reason line when there is none`() {
        let text = CrashReportFormatter.makeReportText(
            kind: "Fatal signal",
            detail: nil,
            callStack: ["0 frame-a"],
            environment: sampleEnvironment,
            date: Date(timeIntervalSince1970: 0),
        )

        #expect(!text.contains("Reason:"))
    }
}
