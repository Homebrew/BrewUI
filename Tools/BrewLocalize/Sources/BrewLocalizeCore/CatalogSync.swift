import Foundation

/// Reproduces Xcode's build-time catalog sync: the compiler emits `.stringsdata` for every source
/// (`-emit-localized-strings`), then `xcstringstool sync` merges them into the target's catalog.
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

    /// Everything lives under one scratch path so incremental builds stay warm between runs.
    public static let scratchPath = ".build/localize"

    /// Builds the package and compiles the app sources, emitting string data for every file.
    public static func extract(root: URL) throws -> StringsDataIndex {
        let scratch = root.appendingPathComponent(scratchPath)
        let packageStringsData = scratch.appendingPathComponent("stringsdata")
        let appStringsData = scratch.appendingPathComponent("stringsdata-app")
        let appObjects = scratch.appendingPathComponent("app-objects")
        for directory in [packageStringsData, appStringsData, appObjects] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        try run([
            "swift", "build", "--package-path", root.path, "--scratch-path", scratch.path,
            "-Xswiftc", "-emit-localized-strings",
            "-Xswiftc", "-emit-localized-strings-path", "-Xswiftc", packageStringsData.path,
        ])

        let appSources = CatalogLocation(path: CatalogLocation.appCatalogPath)
            .sourceFiles(root: root)
            .map { root.appendingPathComponent($0).path }
        if !appSources.isEmpty {
            try run(
                appCompileArguments(scratch: scratch, stringsData: appStringsData) + appSources,
                currentDirectory: appObjects,
            )
        }
        return StringsDataIndex(directories: [packageStringsData, appStringsData])
    }

    /// Syncs one catalog in place. With `check`, the catalog on disk is left untouched and
    /// `Outcome.diff` describes what a real sync would change.
    public static func sync(
        _ location: CatalogLocation,
        root: URL,
        index: StringsDataIndex,
        check: Bool,
    ) throws -> Outcome {
        let fileManager = FileManager.default
        let catalogURL = root.appendingPathComponent(location.path)
        let sources = location.sourceFiles(root: root).map { root.appendingPathComponent($0).path }
        let stringsdata = try index.files(for: sources).map(\.path)

        let scratch = fileManager.temporaryDirectory
            .appendingPathComponent("brew-localize-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: scratch) }

        let target = check ? scratch.appendingPathComponent(CatalogLocation.fileName) : catalogURL
        if check {
            try fileManager.copyItem(at: catalogURL, to: target)
        }
        // `sync` requires at least one stringsdata; with no sources there is nothing to merge.
        if !stringsdata.isEmpty {
            try run(["xcstringstool", "sync", target.path, "--stringsdata"] + stringsdata)
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

    /// Mirrors the app target's build settings in `Homebrew.xcodeproj` closely enough to type-check.
    /// Object files land in the working directory and are never used.
    private static func appCompileArguments(scratch: URL, stringsData: URL) -> [String] {
        let sdk = (try? capture(["--sdk", "macosx", "--show-sdk-path"], allowedStatuses: [0]))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var arguments = [
            "swiftc", "-c", "-parse-as-library", "-module-name", "Homebrew",
            "-target", "\(hostArchitecture())-apple-macos26.0", "-sdk", sdk,
            "-swift-version", "6", "-DDEBUG",
            "-default-isolation", "MainActor",
            "-enable-upcoming-feature", "MemberImportVisibility",
            "-I", scratch.appendingPathComponent("debug/Modules").path,
            "-emit-localized-strings", "-emit-localized-strings-path", stringsData.path,
        ]
        for moduleMap in cModuleMaps(under: scratch.appendingPathComponent("checkouts")) {
            arguments += ["-I", moduleMap.deletingLastPathComponent().path]
        }
        return arguments
    }

    private static func cModuleMaps(under directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        var maps: [URL] = []
        for case let url as URL in enumerator where url.lastPathComponent == "module.modulemap" {
            maps.append(url)
        }
        return maps.sorted { $0.path < $1.path }
    }

    private static func hostArchitecture() -> String {
        #if arch(x86_64)
            "x86_64"
        #else
            "arm64"
        #endif
    }

    @discardableResult
    private static func run(_ arguments: [String], currentDirectory: URL? = nil) throws -> String {
        try capture(arguments, allowedStatuses: [0], currentDirectory: currentDirectory)
    }

    /// `diff` exits 1 when files differ, so callers that expect that pass `allowedStatuses`.
    private static func capture(
        _ arguments: [String],
        allowedStatuses: Set<Int32> = [0, 1],
        currentDirectory: URL? = nil,
    ) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
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
