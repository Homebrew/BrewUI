//
//  CrashReportStore.swift
//  Brew
//

import Foundation

/// Persists and enumerates crash reports on disk as individual
/// `crash-<epochMillis>.log` text files — a format a signal handler can write
/// via a raw file descriptor (see `CrashReportInstaller`). The timestamp in the
/// name is provided by the caller (for fatal signals it's the install-time `date`).
/// A small `Sendable` value holding only the directory, mirroring `CatalogueCache`.
public struct CrashReportStore: Sendable {
    private let directoryURL: URL

    public init(directoryURL: URL? = nil) {
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL()
    }

    public func reportFileURL(for date: Date) -> URL {
        let millis = Int((date.timeIntervalSince1970 * 1000).rounded())
        return directoryURL.appendingPathComponent("crash-\(millis).log")
    }

    public func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
        )
    }

    /// The signal path appends to one file per launch and the exception path can be handed an
    /// unbounded backtrace, so a single report is clamped on the way to disk — and again on the way
    /// back, because an oversized file written before this limit existed would otherwise still reach
    /// the sheet, where laying out one string of that size wedges the launch it belongs to.
    /// The dialog renders a report as one `Text`, which lays out in full: 128 KB of it costs six
    /// seconds of launch. A capped call stack fits in a fraction of this.
    public static let maximumReportBytes = 16 * 1024

    @discardableResult
    public func save(text: String, date: Date) throws -> CrashReport {
        try ensureDirectoryExists()
        let url = reportFileURL(for: date)
        let clamped = Self.clamped(text)
        try Data(clamped.utf8).write(to: url, options: .atomic)
        return CrashReport(id: url.lastPathComponent, capturedAt: date, text: clamped)
    }

    /// All persisted reports, oldest first; unreadable files are skipped so a
    /// broken report can't block the app.
    public func pendingReports() -> [CrashReport] {
        let fileManager = FileManager.default
        guard let names = try? fileManager.contentsOfDirectory(atPath: directoryURL.path) else {
            return []
        }

        return names
            .compactMap(makeReport(fromFileNamed:))
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    public func remove(_ report: CrashReport) {
        try? FileManager.default.removeItem(at: directoryURL.appendingPathComponent(report.id))
    }

    public func removeAll() {
        for report in pendingReports() {
            remove(report)
        }
    }

    private func makeReport(fromFileNamed name: String) -> CrashReport? {
        guard name.hasPrefix("crash-"), name.hasSuffix(".log") else {
            return nil
        }

        let stem = name.dropFirst("crash-".count).dropLast(".log".count)
        guard let millis = Int(stem) else {
            return nil
        }

        let url = directoryURL.appendingPathComponent(name)
        guard let text = readClampedText(at: url) else {
            return nil
        }

        return CrashReport(
            id: name,
            capturedAt: Date(timeIntervalSince1970: Double(millis) / 1000),
            text: text,
        )
    }

    /// Reads the leading bytes rather than the file, so an oversized report costs a page, not its size.
    private func readClampedText(at url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: Self.maximumReportBytes) else {
            return nil
        }
        guard let text = Self.decoded(data) else {
            return nil
        }
        let isTruncated = (try? handle.read(upToCount: 1))??.isEmpty == false
        return isTruncated ? text + Self.truncationMarker : text
    }

    /// Cutting at a byte count can split a character, so give back the bytes that make a whole one.
    private static func decoded(_ data: Data) -> String? {
        for droppedBytes in 0 ... 3 {
            if let text = String(data: data.dropLast(droppedBytes), encoding: .utf8) {
                return text
            }
        }
        return nil
    }

    private static func clamped(_ text: String) -> String {
        guard text.utf8.count > maximumReportBytes else {
            return text
        }
        return String(text.prefix(maximumReportBytes)) + truncationMarker
    }

    private static let truncationMarker = "\n\n… report truncated …\n"

    private static func defaultDirectoryURL() -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base
            .appendingPathComponent("Brew", isDirectory: true)
            .appendingPathComponent("CrashReports", isDirectory: true)
    }
}
