//
//  CrashReportStore.swift
//  Brew
//

import Foundation

/// Persists and enumerates crash reports on disk.
///
/// Reports live as individual `crash-<epochMillis>.log` text files in a
/// dedicated directory so they can be written at crash time (via a raw file
/// descriptor in a signal handler — see `CrashReportInstaller`) and read back
/// on the next launch. The epoch-millis file name encodes the capture time,
/// so no separate index or metadata file is needed.
///
/// The type is a small `Sendable` value: it holds only the directory URL and
/// reaches for `FileManager.default` itself, mirroring `CatalogueCache`.
public struct CrashReportStore: Sendable {
    private let directoryURL: URL

    /// - Parameter directoryURL: overrides the default location; tests pass a
    ///   unique temporary directory to stay isolated.
    public init(directoryURL: URL? = nil) {
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL()
    }

    /// The directory holding crash reports. Exposed so the installer can build
    /// a file path up-front (before any crash) without duplicating the layout.
    public var directory: URL {
        directoryURL
    }

    /// The deterministic file URL for a report captured at `date`.
    public func reportFileURL(for date: Date) -> URL {
        let millis = Int((date.timeIntervalSince1970 * 1000).rounded())
        return directoryURL.appendingPathComponent("crash-\(millis).log")
    }

    /// Creates the reports directory if it does not already exist.
    public func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
        )
    }

    /// Writes a full report and returns the persisted value.
    @discardableResult
    public func save(text: String, date: Date) throws -> CrashReport {
        try ensureDirectoryExists()
        let url = reportFileURL(for: date)
        try Data(text.utf8).write(to: url, options: .atomic)
        return CrashReport(id: url.lastPathComponent, capturedAt: date, text: text)
    }

    /// All persisted reports, oldest first. Unreadable or malformed files are
    /// skipped rather than surfaced — a broken report must not block the app.
    public func pendingReports() -> [CrashReport] {
        let fileManager = FileManager.default
        guard let names = try? fileManager.contentsOfDirectory(atPath: directoryURL.path) else {
            return []
        }

        return names
            .compactMap(makeReport(fromFileNamed:))
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    /// Deletes a single report. Best-effort: a failure to delete is not worth
    /// crashing over.
    public func remove(_ report: CrashReport) {
        try? FileManager.default.removeItem(at: directoryURL.appendingPathComponent(report.id))
    }

    /// Deletes every persisted report.
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
