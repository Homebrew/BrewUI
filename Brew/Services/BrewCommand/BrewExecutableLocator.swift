//
//  BrewExecutableLocator.swift
//  Brew
//

import Foundation

/// Resolves the `brew` binary without relying on a single hard-coded prefix (`AGENTS.md`).
struct BrewExecutableLocator: BrewExecutableLocating {
    private let isExecutableAtPath: @Sendable (String) -> Bool
    /// When set (tests only), skip filesystem probing.
    private let overrideURL: URL?

    nonisolated init(
        isExecutableAtPath: @escaping @Sendable (String) -> Bool = { path in
            FileManager.default.isExecutableFile(atPath: path)
        },
    ) {
        self.isExecutableAtPath = isExecutableAtPath
        overrideURL = nil
    }

    nonisolated init(overrideURL: URL) {
        isExecutableAtPath = { path in
            FileManager.default.isExecutableFile(atPath: path)
        }
        self.overrideURL = overrideURL
    }

    /// Tries Apple Silicon default, then Intel default.
    nonisolated func findBrewExecutable() throws -> URL {
        if let overrideURL {
            return overrideURL
        }
        let candidates = [
            URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            URL(fileURLWithPath: "/usr/local/bin/brew"),
        ]
        for url in candidates {
            let path = url.path
            let executable = isExecutableAtPath(path)
            let resolvedPath = url.resolvingSymlinksInPath().path
            let resolvedExecutable = isExecutableAtPath(resolvedPath)
            if executable {
                return url
            }
            // `isExecutableFile(atPath:)` tests the symlink node, not its destination (Foundation docs).
            if resolvedExecutable {
                return URL(fileURLWithPath: resolvedPath)
            }
        }
        throw BrewLookupError.executableNotFound
    }
}
