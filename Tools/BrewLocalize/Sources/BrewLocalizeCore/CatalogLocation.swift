import Foundation

/// A catalog on disk and the target directory whose Swift sources feed it.
public struct CatalogLocation: Equatable, Sendable {
    public static let fileName = "Localizable.xcstrings"
    public static let appCatalogPath = "Homebrew/\(fileName)"

    /// Repo-relative catalog path, e.g. `Sources/BrewFeatureDoctor/Resources/Localizable.xcstrings`.
    public let path: String
    /// Repo-relative directory scanned for `*.swift`, e.g. `Sources/BrewFeatureDoctor`.
    public let sourceDirectory: String

    public init(path: String) {
        self.path = path
        let components = path.split(separator: "/").map(String.init)
        if path == Self.appCatalogPath {
            sourceDirectory = "Homebrew"
        } else {
            sourceDirectory = components.dropLast(2).joined(separator: "/")
        }
    }

    public var isApp: Bool {
        path == Self.appCatalogPath
    }

    /// Only UI targets may hold copy; everything else throws typed errors and lets the UI layer word them.
    public var isInAllowedLayer: Bool {
        if isApp {
            return true
        }
        let components = path.split(separator: "/").map(String.init)
        guard components.count == 4, components[0] == "Sources", components[2] == "Resources",
              components[3] == Self.fileName
        else {
            return false
        }
        let target = components[1]
        return target == "BrewUIComponents" || target.hasPrefix("BrewFeature")
    }

    /// Finds every catalog under `root`, sorted by path.
    public static func discover(root: URL, fileManager: FileManager = .default) -> [CatalogLocation] {
        var paths: [String] = []
        for top in ["Sources", "Homebrew"] {
            let base = root.appendingPathComponent(top)
            guard let enumerator = fileManager.enumerator(at: base, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let url as URL in enumerator where url.lastPathComponent == fileName {
                paths.append(relativePath(of: url, to: root))
            }
        }
        return paths.sorted().map(CatalogLocation.init(path:))
    }

    /// Swift files under `sourceDirectory`, sorted so extraction is deterministic.
    public func sourceFiles(root: URL, fileManager: FileManager = .default) -> [String] {
        let base = root.appendingPathComponent(sourceDirectory)
        guard let enumerator = fileManager.enumerator(at: base, includingPropertiesForKeys: nil) else {
            return []
        }
        var files: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            files.append(Self.relativePath(of: url, to: root))
        }
        return files.sorted()
    }

    private static func relativePath(of url: URL, to root: URL) -> String {
        let rootPath = root.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        return path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : path
    }
}
