import Foundation

/// The `.stringsdata` files the compiler emitted, keyed by the Swift source each one came from.
public struct StringsDataIndex: Sendable {
    public enum Failure: Error, Equatable, CustomStringConvertible {
        case missing(sources: [String])

        public var description: String {
            switch self {
            case let .missing(sources):
                "No compiler string data for:\n  " + sources.joined(separator: "\n  ")
                    + "\nA file elsewhere with the same name overwrote it, or the build skipped it. Rename one of the pair."
            }
        }
    }

    private var filesBySource: [String: URL] = [:]

    public init() {}

    /// Reads every `.stringsdata` under `directories`; a later directory wins on duplicate sources.
    public init(directories: [URL], fileManager: FileManager = .default) {
        for directory in directories {
            let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
            for name in names where name.hasSuffix(".stringsdata") {
                let url = directory.appendingPathComponent(name)
                if let source = Self.source(of: url) {
                    filesBySource[source] = url
                }
            }
        }
    }

    /// The stringsdata for exactly `sources` (absolute paths), failing if any is unaccounted for.
    public func files(for sources: [String]) throws -> [URL] {
        var files: [URL] = []
        var missing: [String] = []
        for source in sources {
            if let url = filesBySource[URL(fileURLWithPath: source).standardizedFileURL.path] {
                files.append(url)
            } else {
                missing.append(source)
            }
        }
        guard missing.isEmpty else {
            throw Failure.missing(sources: missing)
        }
        return files
    }

    private static func source(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let source = object["source"] as? String
        else {
            return nil
        }
        return URL(fileURLWithPath: source).standardizedFileURL.path
    }
}
