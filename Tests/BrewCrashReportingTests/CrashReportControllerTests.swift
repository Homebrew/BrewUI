//
//  CrashReportControllerTests.swift
//  BrewTests
//

@testable import BrewCrashReporting
import Foundation
import Testing

@MainActor
struct CrashReportControllerTests {
    private let defaults: UserDefaults
    private let root: URL

    init() throws {
        let name = "CrashReportControllerTests-\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: name))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fixture = try #require(Bundle.module.url(
            forResource: "stack-guard-sigsegv",
            withExtension: "ips",
            subdirectory: "Fixtures",
        ))
        try Data(contentsOf: fixture).write(to: root.appendingPathComponent("Homebrew-2026-09-20-223007.ips"))
    }

    private func makeController() -> CrashReportController {
        CrashReportController(directory: DiagnosticReportDirectory(directoryURL: root), defaults: defaults)
    }

    @Test func `loading surfaces a report macOS wrote`() async {
        let controller = makeController()

        await controller.loadPendingReports()

        #expect(controller.currentReport?.id == "Homebrew-2026-09-20-223007.ips")
        #expect(controller.currentReport?.text.contains("Exception: EXC_BAD_ACCESS (SIGSEGV)") == true)
    }

    @Test func `discarding acknowledges the report and leaves the file for macOS`() async throws {
        let controller = makeController()
        await controller.loadPendingReports()
        let report = try #require(controller.currentReport)

        controller.discard(report)

        #expect(controller.currentReport == nil)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(report.id).path))
    }

    @Test func `an acknowledged report is not surfaced on the next launch`() async throws {
        let first = makeController()
        await first.loadPendingReports()
        try first.discard(#require(first.currentReport))

        let next = makeController()
        await next.loadPendingReports()

        #expect(next.currentReport == nil)
    }

    @Test func `current report is nil when nothing is pending`() async {
        let controller = CrashReportController(
            directory: DiagnosticReportDirectory(directoryURL: root.appendingPathComponent("empty")),
            defaults: defaults,
        )

        await controller.loadPendingReports()

        #expect(controller.currentReport == nil)
    }
}
