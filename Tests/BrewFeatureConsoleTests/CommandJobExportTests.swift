//
//  CommandJobExportTests.swift
//  BrewTests
//

import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureConsole
import BrewRepositories
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation
import Testing

@MainActor
struct CommandJobExportTests {
    @Test func `formattedOutputForExport joins lines with newlines`() {
        let job = CommandJob.materialize(
            id: BrewOperationID(kind: .formula, name: "gh"),
            kind: .installFormula,
            phase: .running(.installFormula),
        )
        job.appendOutput(BrewCommandOutputLine(stream: .stdout, text: "first"))
        job.appendOutput(BrewCommandOutputLine(stream: .stdout, text: "second"))

        #expect(job.formattedOutputForExport() == "first\nsecond")
    }

    @Test func `formattedOutputForExport prefixes stderr lines for disambiguation`() {
        let job = CommandJob.materialize(
            id: BrewOperationID(kind: .formula, name: "gh"),
            kind: .installFormula,
            phase: .running(.installFormula),
        )
        job.appendOutput(BrewCommandOutputLine(stream: .stdout, text: "==> downloading"))
        job.appendOutput(BrewCommandOutputLine(stream: .stderr, text: "warning: x"))
        job.appendOutput(BrewCommandOutputLine(stream: .stdout, text: "==> linking"))

        #expect(job.formattedOutputForExport() == "==> downloading\n[stderr] warning: x\n==> linking")
    }

    @Test func `formattedOutputForExport strips ANSI colour codes`() {
        let job = CommandJob.materialize(
            id: BrewOperationID(kind: .formula, name: "gh"),
            kind: .installFormula,
            phase: .running(.installFormula),
        )
        job.appendOutput(BrewCommandOutputLine(stream: .stdout, text: "\u{1B}[1;34m==>\u{1B}[0m Pouring"))
        job.appendOutput(BrewCommandOutputLine(stream: .stderr, text: "\u{1B}[31mWarning:\u{1B}[0m x"))

        #expect(job.formattedOutputForExport() == "==> Pouring\n[stderr] Warning: x")
    }

    @Test func `formattedOutputForExport on empty buffer is empty string`() {
        let job = CommandJob.materialize(
            id: BrewOperationID(kind: .formula, name: "gh"),
            kind: .installFormula,
            phase: .running(.installFormula),
        )

        #expect(job.formattedOutputForExport() == "")
    }

    @Test func `suggestedExportFilename uses timestamped pattern with sanitized command`() {
        let job = CommandJob.materialize(
            id: BrewOperationID(kind: .formula, name: "gh"),
            kind: .installFormula,
            phase: .running(.installFormula),
        )
        // 2026-05-27 13:45:09 UTC
        let date = Date(timeIntervalSince1970: 1_780_205_109)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current

        let filename = job.suggestedExportFilename(now: date)

        // Format is locale-independent (en_US_POSIX, yyyy-MM-dd-HHmmss) but timezone-dependent;
        // assert the prefix + .log suffix + correct number of segments.
        #expect(filename.hasPrefix("brewui-brew-install-gh-"))
        #expect(filename.hasSuffix(".log"))
        // Pattern: brewui-brew-install-gh-yyyy-MM-dd-HHmmss.log
        let core = filename.dropFirst("brewui-brew-install-gh-".count).dropLast(".log".count)
        #expect(core.count == "yyyy-MM-dd-HHmmss".count)
    }

    @Test func `suggestedExportFilename replaces unsafe path characters`() {
        let job = CommandJob(
            id: BrewOperationID(kind: .formula, name: "weird"),
            command: "brew weird /path:colon thing",
            startedAt: Date(),
            phase: .idle,
        )

        let filename = job.suggestedExportFilename()

        #expect(!filename.contains(" "))
        #expect(!filename.contains("/"))
        #expect(!filename.contains(":"))
    }
}
