//
//  DiagnosticReportTests.swift
//  BrewTests
//

@testable import BrewCrashReporting
import Foundation
import Testing

private func loadFixture() throws -> Data {
    let url = try #require(Bundle.module.url(
        forResource: "stack-guard-sigsegv",
        withExtension: "ips",
        subdirectory: "Fixtures",
    ))
    return try Data(contentsOf: url)
}

struct DiagnosticReportParserTests {
    @Test func `identifies the app, build and OS from the body`() throws {
        let report = try DiagnosticReportParser.parse(loadFixture())

        #expect(report.bundleIdentifier == "sh.brew.app")
        #expect(report.appVersion == "0.0.0")
        #expect(report.buildNumber == "0")
        #expect(report.osVersion == "macOS 26.5 (25F71)")
    }

    @Test func `capture time comes from the body's fractional timestamp`() throws {
        let report = try DiagnosticReportParser.parse(loadFixture())

        #expect(report.capturedAt.ISO8601Format() == "2026-09-20T12:30:03Z")
    }

    @Test func `exception summary joins type, signal, subtype and message`() throws {
        let report = try DiagnosticReportParser.parse(loadFixture())

        #expect(report.exceptionSummary == "EXC_BAD_ACCESS (SIGSEGV) – "
            + "KERN_PROTECTION_FAILURE at 0x000000016f50bec0 – "
            + "Could not determine thread index for stack guard region")
        #expect(report.terminationReason == "Segmentation fault: 11")
    }

    @Test func `crashed thread frames resolve image names and source locations`() throws {
        let report = try DiagnosticReportParser.parse(loadFixture())

        #expect(report.crashedThreadLabel == "Thread 0 (com.apple.main-thread)")
        #expect(report.crashedThreadFrames[3] == DiagnosticReport.Frame(
            imageName: "Homebrew.debug.dylib",
            imageOffset: 4_090_228,
            symbol: "writeBacktrace(to:)",
            symbolOffset: 168,
            sourceFile: "CrashReportInstaller.swift",
            sourceLine: 126,
        ))
    }

    @Test func `compiler-generated thunks carry no source file`() throws {
        let report = try DiagnosticReportParser.parse(loadFixture())

        #expect(report.crashedThreadFrames[5].symbol?.hasPrefix("@objc closure") == true)
        #expect(report.crashedThreadFrames[5].sourceFile == nil)
    }

    @Test func `a signal crash has no last exception backtrace`() throws {
        let report = try DiagnosticReportParser.parse(loadFixture())

        #expect(report.lastExceptionBacktrace.isEmpty)
        #expect(report.applicationSpecificInformation.isEmpty)
    }

    @Test func `a file without the header line is rejected`() {
        #expect(throws: DiagnosticReportParsingError.missingHeader) {
            try DiagnosticReportParser.parse(Data("{}".utf8))
        }
    }
}

struct DiagnosticReportFormatterTests {
    @Test func `report text keeps the header shape the issue title relies on`() throws {
        let text = try DiagnosticReportFormatter.makeReportText(DiagnosticReportParser.parse(loadFixture()))

        #expect(text.hasPrefix("""
        Homebrew.app crash report
        =========================
        Date: 2026-09-20T12:30:03Z
        App version: 0.0.0 (0)
        macOS: macOS 26.5 (25F71)
        Exception: EXC_BAD_ACCESS (SIGSEGV)
        """))
    }

    @Test func `a long backtrace is cut with a count of what was dropped`() throws {
        var report = try DiagnosticReportParser.parse(loadFixture())
        let frame = try #require(report.crashedThreadFrames.first)
        report = DiagnosticReport(
            bundleIdentifier: report.bundleIdentifier,
            capturedAt: report.capturedAt,
            appVersion: report.appVersion,
            buildNumber: report.buildNumber,
            osVersion: report.osVersion,
            exceptionSummary: report.exceptionSummary,
            terminationReason: report.terminationReason,
            applicationSpecificInformation: [],
            lastExceptionBacktrace: [],
            crashedThreadLabel: report.crashedThreadLabel,
            crashedThreadFrames: Array(repeating: frame, count: 500),
        )

        let text = DiagnosticReportFormatter.makeReportText(report)

        #expect(text.hasSuffix("… 436 more frames …"))
        #expect(!text.contains("\n64\t"))
    }

    @Test func `frames read like Apple's translated report`() throws {
        let text = try DiagnosticReportFormatter.makeReportText(DiagnosticReportParser.parse(loadFixture()))

        #expect(text.contains("Thread 0 (com.apple.main-thread) crashed:\n"))
        #expect(text.contains("3\tHomebrew.debug.dylib\twriteBacktrace(to:) + 168 (CrashReportInstaller.swift:126)"))
    }
}

struct DiagnosticReportDirectoryTests {
    private func makeDirectory(files: [String]) throws -> DiagnosticReportDirectory {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiagnosticReportDirectoryTests-\(UUID().uuidString)", isDirectory: true)
        let fixture = try loadFixture()
        for file in files {
            let url = root.appendingPathComponent(file)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            try fixture.write(to: url)
        }
        return DiagnosticReportDirectory(directoryURL: root)
    }

    @Test func `finds this app's reports in the directory and in Retired`() throws {
        let directory = try makeDirectory(files: [
            "Homebrew-2026-09-20-223007.ips",
            "Retired/Homebrew-2026-09-19-120000.ips",
            "Xcode-2026-09-16-221857.ips",
            "Homebrew-2026-09-18-000000.diag",
        ])

        let names = directory.reports(capturedAfter: .distantPast).map(\.fileName)

        #expect(names.sorted() == ["Homebrew-2026-09-19-120000.ips", "Homebrew-2026-09-20-223007.ips"])
    }

    @Test func `reports captured before the cut-off are ignored`() throws {
        let directory = try makeDirectory(files: ["Homebrew-2026-09-20-223007.ips"])
        let afterCapture = try #require(ISO8601DateFormatter().date(from: "2026-09-20T12:30:04Z"))

        #expect(directory.reports(capturedAfter: afterCapture).isEmpty)
    }

    @Test func `a missing directory yields no reports`() {
        let directory = DiagnosticReportDirectory(
            directoryURL: URL(fileURLWithPath: "/nonexistent/DiagnosticReports"),
        )

        #expect(directory.reports(capturedAfter: .distantPast).isEmpty)
    }
}
