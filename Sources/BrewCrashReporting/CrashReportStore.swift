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

    @discardableResult
    public func save(text: String, date: Date) throws -> CrashReport {
        try ensureDirectoryExists()
        let url = reportFileURL(for: date)
        try Data(text.utf8).write(to: url, options: .atomic)
        return CrashReport(id: url.lastPathComponent, capturedAt: date, text: text)
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
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        return CrashReport(
            id: name,
            capturedAt: Date(timeIntervalSince1970: Double(millis) / 1000),
            text: text,
        )
    }

    private static func defaultDirectoryURL() -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base
            .appendingPathComponent("Brew", isDirectory: true)
            .appendingPathComponent("CrashReports", isDirectory: true)
    }
}
