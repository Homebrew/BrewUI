//
//  BrewExecutableLocator.swift
//  Brew
//

import Foundation

/// Resolves the `brew` binary without relying on a single hard-coded prefix (`AGENTS.md`).
struct BrewExecutableLocator: BrewExecutableLocating {
    private let fileManager: FileManager
    /// When set (tests only), skip filesystem probing.
    private let overrideURL: URL?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        overrideURL = nil
    }

    init(overrideURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.overrideURL = overrideURL
    }

    /// Tries Apple Silicon default, then Intel default.
    func findBrewExecutable() throws -> URL {
        if let overrideURL {
            return overrideURL
        }
        let candidates = [
            URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
            URL(fileURLWithPath: "/usr/local/bin/brew")
        ]
        for url in candidates {
            let path = url.path
            let executable = fileManager.isExecutableFile(atPath: path)
            let resolvedPath = url.resolvingSymlinksInPath().path
            let resolvedExecutable = fileManager.isExecutableFile(atPath: resolvedPath)
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
