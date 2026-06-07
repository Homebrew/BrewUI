//
//  BrewEnvFileLocator.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Resolves the user-level `brew.env` Homebrew itself sources, honouring the same probe order:
/// `$HOMEBREW_USER_CONFIG_HOME` → `${XDG_CONFIG_HOME:-$HOME/.config}/homebrew` → legacy `$HOME/.homebrew`.
///
/// Reads return the first existing file (legacy included so users mid-migration aren't surprised).
/// Writes default to the modern XDG path when nothing exists yet — never the legacy path — so new
/// files land where current Homebrew documents.
public struct BrewEnvFileLocator: Sendable {
    private let environment: [String: String]
    private let fileExists: @Sendable (String) -> Bool

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileExists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
    ) {
        self.environment = environment
        self.fileExists = fileExists
    }

    /// The single path to read from / write to. Returns the first existing probe path; if nothing
    /// exists, returns the preferred path to create a new file at.
    public func locate() -> URL {
        for path in probePaths() where fileExists(path.path) {
            return path
        }
        return preferredCreationPath()
    }

    /// First existing probe path, or `nil` if no file exists yet (used by tests that need to distinguish
    /// "found" from "default destination").
    public func existingPath() -> URL? {
        probePaths().first { fileExists($0.path) }
    }

    /// Where a fresh `brew.env` should be created. The legacy `~/.homebrew` path is intentionally
    /// excluded from new-file candidates so we don't grow the deprecated layout.
    public func preferredCreationPath() -> URL {
        if let homebrewConfigHome = environment["HOMEBREW_USER_CONFIG_HOME"], !homebrewConfigHome.isEmpty {
            return URL(fileURLWithPath: homebrewConfigHome).appendingPathComponent("brew.env")
        }
        if let xdg = environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            return URL(fileURLWithPath: xdg).appendingPathComponent("homebrew/brew.env")
        }
        return homeDirectory().appendingPathComponent(".config/homebrew/brew.env")
    }

    private func probePaths() -> [URL] {
        var paths: [URL] = []
        if let homebrewConfigHome = environment["HOMEBREW_USER_CONFIG_HOME"], !homebrewConfigHome.isEmpty {
            paths.append(URL(fileURLWithPath: homebrewConfigHome).appendingPathComponent("brew.env"))
        }
        if let xdg = environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            paths.append(URL(fileURLWithPath: xdg).appendingPathComponent("homebrew/brew.env"))
        }
        let home = homeDirectory()
        paths.append(home.appendingPathComponent(".config/homebrew/brew.env"))
        paths.append(home.appendingPathComponent(".homebrew/brew.env"))
        return paths
    }

    private func homeDirectory() -> URL {
        if let home = environment["HOME"], !home.isEmpty {
            return URL(fileURLWithPath: home)
        }
        return URL(fileURLWithPath: NSHomeDirectory())
    }
}
