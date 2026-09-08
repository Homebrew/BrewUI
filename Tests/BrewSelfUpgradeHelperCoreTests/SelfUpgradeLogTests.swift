//
//  SelfUpgradeLogTests.swift
//  BrewSelfUpgradeHelperCoreTests
//

import BrewSelfUpgradeHelperCore
import Foundation
import Testing

/// The log is the only account of what happened: the app is not running while the upgrade is.
struct SelfUpgradeLogTests {
    private func makeFileURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("self-upgrade-log-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("self-upgrade.log")
    }

    private func contents(of fileURL: URL) throws -> String {
        try String(contentsOf: fileURL, encoding: .utf8)
    }

    @Test func `lines are written in order`() throws {
        let fileURL = makeFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let log = SelfUpgradeLog(fileURL: fileURL)
        log.begin()
        log.write("first")
        log.write("second")
        log.end()

        let lines = try contents(of: fileURL).split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].hasSuffix("first"))
        #expect(lines[1].hasSuffix("second"))
    }

    /// `~/Library/Logs/sh.brew.app` does not exist until the first self-upgrade writes to it.
    @Test func `a missing directory is created`() {
        let fileURL = makeFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let log = SelfUpgradeLog(fileURL: fileURL)
        log.begin()
        log.write("created")
        log.end()

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    /// One self-upgrade per file: after a failure, the previous run's output would only be confusing.
    @Test func `a second run replaces the previous log rather than appending`() throws {
        let fileURL = makeFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let first = SelfUpgradeLog(fileURL: fileURL)
        first.begin()
        first.write("from the first run")
        first.end()

        let second = SelfUpgradeLog(fileURL: fileURL)
        second.begin()
        second.write("from the second run")
        second.end()

        let written = try contents(of: fileURL)
        #expect(written.contains("from the second run"))
        #expect(!written.contains("from the first run"))
    }

    @Test func `every line carries a timestamp`() throws {
        let fileURL = makeFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let fixed = Date(timeIntervalSince1970: 1_760_000_000)
        let log = SelfUpgradeLog(fileURL: fileURL, clock: { fixed })
        log.begin()
        log.write("stamped")
        log.end()

        #expect(try contents(of: fileURL).hasPrefix("[2025-10-09"))
    }

    /// A log that cannot be opened must not stop an upgrade; the writes fall back to stderr.
    @Test func `an unopenable path does not trap the caller`() {
        let log = SelfUpgradeLog(fileURL: URL(fileURLWithPath: "/dev/null/not-a-directory/self-upgrade.log"))
        log.begin()
        log.write("still fine")
        log.end()
    }

    @Test func `a nil file URL writes nothing and still accepts messages`() {
        let log = SelfUpgradeLog(fileURL: nil)
        log.begin()
        log.write("nowhere to go")
        log.end()
    }
}
