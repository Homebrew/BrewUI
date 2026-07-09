//
//  CrashReportControllerTests.swift
//  BrewTests
//

@testable import BrewCrashReporting
import Foundation
import Testing

private func makeTemporaryStore() -> CrashReportStore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CrashReportControllerTests-\(UUID().uuidString)", isDirectory: true)
    return CrashReportStore(directoryURL: directory)
}

@MainActor
struct CrashReportControllerTests {
    @Test func `loading surfaces the oldest report first`() async throws {
        let store = makeTemporaryStore()
        try store.save(text: "older", date: Date(timeIntervalSince1970: 1000))
        try store.save(text: "newer", date: Date(timeIntervalSince1970: 2000))
        let controller = CrashReportController(store: store)

        await controller.loadPendingReports()

        #expect(controller.currentReport?.text == "older")
    }

    @Test func `discarding advances to the next report and deletes it from disk`() async throws {
        let store = makeTemporaryStore()
        try store.save(text: "older", date: Date(timeIntervalSince1970: 1000))
        try store.save(text: "newer", date: Date(timeIntervalSince1970: 2000))
        let controller = CrashReportController(store: store)
        await controller.loadPendingReports()

        let older = try #require(controller.currentReport)
        controller.discard(older)

        #expect(controller.currentReport?.text == "newer")
        #expect(store.pendingReports().map(\.text) == ["newer"])
    }

    @Test func `current report is nil when nothing is pending`() async {
        let controller = CrashReportController(store: makeTemporaryStore())

        await controller.loadPendingReports()

        #expect(controller.currentReport == nil)
    }
}
