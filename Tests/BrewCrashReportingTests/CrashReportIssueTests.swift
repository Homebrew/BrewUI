//
//  CrashReportIssueTests.swift
//  BrewTests
//

@testable import BrewCrashReporting
import Foundation
import Testing

private func queryItems(of url: URL) -> [String: String] {
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    return Dictionary(
        uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") },
    )
}

struct CrashReportIssueTests {
    private func makeReport(text: String) -> CrashReport {
        CrashReport(id: "crash-1.log", capturedAt: Date(timeIntervalSince1970: 0), text: text)
    }

    @Test func `issue url targets the new-issue page on the app repository`() {
        let url = CrashReportIssue.url(for: makeReport(text: "Homebrew.app crash report"))

        #expect(url.absoluteString.hasPrefix("https://github.com/Homebrew/BrewUI/issues/new"))
    }

    @Test func `issue title carries the report summary`() {
        let url = CrashReportIssue.url(for: makeReport(text: "Homebrew.app crash report\n===\nSignal: SIGSEGV"))

        #expect(queryItems(of: url)["title"] == "Crash: Homebrew.app crash report")
    }

    @Test func `issue body embeds the crash log in a code fence`() {
        let url = CrashReportIssue.url(for: makeReport(text: "boom-marker"))

        let body = try? #require(queryItems(of: url)["body"])
        #expect(body?.contains("```\nboom-marker\n```") == true)
    }

    @Test func `oversized logs are truncated with an attach note`() {
        let longText = String(repeating: "x", count: CrashReportIssue.maxBodyLength + 500)
        let url = CrashReportIssue.url(for: makeReport(text: longText))

        let body = try? #require(queryItems(of: url)["body"])
        #expect(body?.contains("truncated") == true)
    }
}
