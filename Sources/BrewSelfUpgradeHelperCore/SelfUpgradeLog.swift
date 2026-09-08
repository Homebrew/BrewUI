//
//  SelfUpgradeLog.swift
//  BrewSelfUpgradeHelperCore
//

import Foundation

/// The app is not running while the upgrade happens, so stderr goes nowhere anyone will look: a file is the
/// only place a failed self-upgrade can explain itself afterwards.
///
/// Written from the caller *and* from the upgrade's drain queue, so every access to the handle goes through
/// the lock; nothing else is mutable.
// swiftlint:disable:next unchecked_sendable
public final class SelfUpgradeLog: @unchecked Sendable {
    private let fileURL: URL?
    private let lock = NSLock()
    private var handle: FileHandle?
    private let clock: @Sendable () -> Date

    /// A log that cannot be opened is not worth failing an upgrade over, so the writer degrades to stderr.
    public init(fileURL: URL?, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.fileURL = fileURL
        self.clock = clock
    }

    /// Truncates, rather than appending forever: one self-upgrade per file, which is what anyone reading it
    /// after a failure wants to see.
    public func begin() {
        guard let fileURL else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            fileManager.createFile(atPath: fileURL.path, contents: nil)
            handle = try FileHandle(forWritingTo: fileURL)
        } catch {
            writeToStandardError("could not open the log at \(fileURL.path): \(error)")
        }
    }

    public func write(_ message: String) {
        let line = "[\(Self.timestamp(clock()))] \(message)\n"
        lock.lock()
        defer { lock.unlock() }
        guard let handle else {
            writeToStandardError(message)
            return
        }
        do {
            try handle.write(contentsOf: Data(line.utf8))
        } catch {
            writeToStandardError(message)
        }
    }

    public func end() {
        lock.lock()
        defer { lock.unlock() }
        try? handle?.close()
        handle = nil
    }

    /// Retained for a run started from a terminal, where it is the only output anyone sees.
    private func writeToStandardError(_ message: String) {
        FileHandle.standardError.write(Data("HomebrewUpgradeHelper: \(message)\n".utf8))
    }

    /// `ISO8601FormatStyle` rather than `ISO8601DateFormatter`: a value type needs no lock of its own.
    private static func timestamp(_ date: Date) -> String {
        date.formatted(.iso8601)
    }
}
