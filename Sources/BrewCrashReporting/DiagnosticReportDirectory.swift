//
//  DiagnosticReportDirectory.swift
//  Brew
//

import Foundation

/// Finds the crash reports macOS wrote for this app; ReportCrash sweeps older ones into `Retired/`.
public struct DiagnosticReportDirectory: Sendable {
    private let directoryURL: URL
    private let processName: String

    public init(directoryURL: URL? = nil, processName: String = "Homebrew") {
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL()
        self.processName = processName
    }

    /// Reports captured after `date`, oldest first. Unreadable files are skipped.
    public func reports(capturedAfter date: Date) -> [(fileName: String, report: DiagnosticReport)] {
        [directoryURL, directoryURL.appendingPathComponent("Retired", isDirectory: true)]
            .flatMap(reportFiles(in:))
            .compactMap { url -> (fileName: String, report: DiagnosticReport)? in
                guard let data = try? Data(contentsOf: url),
                      let report = try? DiagnosticReportParser.parse(data),
                      report.capturedAt > date
                else {
                    return nil
                }
                return (url.lastPathComponent, report)
            }
            .sorted { $0.report.capturedAt < $1.report.capturedAt }
    }

    private func reportFiles(in directory: URL) -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names
            .filter { $0.hasPrefix("\(processName)-") && $0.hasSuffix(".ips") }
            .map { directory.appendingPathComponent($0) }
    }

    static func defaultDirectoryURL() -> URL {
        let fileManager = FileManager.default
        let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)
        return library.appendingPathComponent("Logs/DiagnosticReports", isDirectory: true)
    }
}
