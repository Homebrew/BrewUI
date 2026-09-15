import Foundation

/// Drives `xcstringstool` the same way Xcode's build does: extract `.stringsdata` from the target's
/// sources, then merge them into the catalog (new keys added, missing keys marked stale).
public enum CatalogSync {
    public enum Failure: Error, CustomStringConvertible {
        case toolFailed(command: String, status: Int32, output: String)

        public var description: String {
            switch self {
            case let .toolFailed(command, status, output):
                "\(command) exited \(status)\n\(output)"
            }
        }
    }

    public struct Outcome: Equatable, Sendable {
        public let location: CatalogLocation
        public let changed: Bool
        public let diff: String
    }

    /// Syncs one catalog in place. With `check`, the catalog on disk is left untouched and
    /// `Outcome.diff` describes what a real sync would change.
    public static func sync(_ location: CatalogLocation, root: URL, check: Bool) throws -> Outcome {
        let fileManager = FileManager.default
        let catalogURL = root.appendingPathComponent(location.path)
        let sources = location.sourceFiles(root: root).map { root.appendingPathComponent($0).path }

        let scratch = fileManager.temporaryDirectory
            .appendingPathComponent("brew-localize-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: scratch) }

        let stringsdata = scratch.appendingPathComponent("stringsdata", isDirectory: true)
        try fileManager.createDirectory(at: stringsdata, withIntermediateDirectories: true)
        if !sources.isEmpty {
            try run(["xcstringstool", "extract", "--modern-localizable-strings", "--SwiftUI"]
                + sources + ["-o", stringsdata.path])
        }
        let stringsdataFiles = (try? fileManager.contentsOfDirectory(atPath: stringsdata.path))?
            .filter { $0.hasSuffix(".stringsdata") }
            .sorted()
            .map { stringsdata.appendingPathComponent($0).path } ?? []

        let target = check ? scratch.appendingPathComponent(CatalogLocation.fileName) : catalogURL
        if check {
            try fileManager.copyItem(at: catalogURL, to: target)
        }
        // `sync` requires at least one stringsdata; with no sources there is nothing to merge.
        if !stringsdataFiles.isEmpty {
            try run(["xcstringstool", "sync", target.path, "--stringsdata"] + stringsdataFiles)
        }

        guard check else {
            return Outcome(location: location, changed: false, diff: "")
        }
        let before = try Data(contentsOf: catalogURL)
        let after = try Data(contentsOf: target)
        guard before != after else {
            return Outcome(location: location, changed: false, diff: "")
        }
        let diff = (try? capture(["diff", "-u", "--label", "a/\(location.path)", "--label", "b/\(location.path)",
                                  catalogURL.path, target.path])) ?? ""
        return Outcome(location: location, changed: true, diff: diff)
    }

    @discardableResult
    private static func run(_ arguments: [String]) throws -> String {
        try capture(arguments, allowedStatuses: [0])
    }

    /// `diff` exits 1 when files differ, so callers that expect that pass `allowedStatuses`.
    private static func capture(_ arguments: [String], allowedStatuses: Set<Int32> = [0, 1]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(bytes: data, encoding: .utf8) ?? ""
        guard allowedStatuses.contains(process.terminationStatus) else {
            throw Failure.toolFailed(
                command: arguments.prefix(2).joined(separator: " "),
                status: process.terminationStatus,
                output: output,
            )
        }
        return output
    }
}
