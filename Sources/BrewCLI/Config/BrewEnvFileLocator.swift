//
//  BrewEnvFileLocator.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Resolves the user-level `brew.env` that `brew` itself sources, matching the resolution order in
/// `bin/brew` master: `${XDG_CONFIG_HOME}/homebrew/brew.env`, else
/// `${HOMEBREW_XDG_CONFIG_HOME}/homebrew/brew.env`, else `${HOME}/.homebrew/brew.env`.
///
/// Reads return the first existing path. Writes use the same chain — without `XDG_CONFIG_HOME` or
/// `HOMEBREW_XDG_CONFIG_HOME` set, new files land at `${HOME}/.homebrew/brew.env` (the default
/// `brew` actually reads), not at `${HOME}/.config/homebrew/brew.env`.
///
/// Out of scope here: `/etc/homebrew/brew.env`, `${HOMEBREW_PREFIX}/etc/homebrew/brew.env`, and
/// `HOMEBREW_SYSTEM_ENV_TAKES_PRIORITY` precedence. Those would matter for an "effective value"
/// view that shows what `brew` will see after layering system + prefix + user files.
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

    /// Where a fresh `brew.env` should be created — same chain as the probe order.
    public func preferredCreationPath() -> URL {
        probePaths().first ?? homeDirectory().appendingPathComponent(".homebrew/brew.env")
    }

    private func probePaths() -> [URL] {
        var paths: [URL] = []
        if let xdg = environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            paths.append(URL(fileURLWithPath: xdg).appendingPathComponent("homebrew/brew.env"))
        } else if let homebrewXDG = environment["HOMEBREW_XDG_CONFIG_HOME"], !homebrewXDG.isEmpty {
            paths.append(URL(fileURLWithPath: homebrewXDG).appendingPathComponent("homebrew/brew.env"))
        } else {
            paths.append(homeDirectory().appendingPathComponent(".homebrew/brew.env"))
        }
        return paths
    }

    private func homeDirectory() -> URL {
        if let home = environment["HOME"], !home.isEmpty {
            return URL(fileURLWithPath: home)
        }
        return URL(fileURLWithPath: NSHomeDirectory())
    }
}
