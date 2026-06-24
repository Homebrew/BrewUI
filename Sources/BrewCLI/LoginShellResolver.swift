//
//  LoginShellResolver.swift
//  BrewCLI
//

import Darwin
import Foundation

/// Resolves the current user's login shell from Directory Services (`getpwuid` reads the same
/// backing store as `dscl . -read /Users/<user> UserShell`, without a subprocess).
///
/// Why this exists: a GUI process launched from Finder/Dock/launchd inherits a stripped environment
/// — `$SHELL` may be stale or absent and must not be consulted. The login shell is the input to
/// ``LoginShellBrewCommandRunner``, which then spawns brew under `<shell> -l -i -c` so the user's
/// profile files load and the subprocess sees the same world as Terminal.
public struct LoginShellResolver: Sendable {
    /// Default fallback when Directory Services is unreadable — modern macOS ships with zsh as the
    /// default user shell.
    public static let defaultFallback = URL(fileURLWithPath: "/bin/zsh")

    private let lookup: @Sendable () -> URL?
    private let fallback: URL

    public init(
        lookup: @escaping @Sendable () -> URL? = LoginShellResolver.directoryServicesLookup,
        fallback: URL = LoginShellResolver.defaultFallback,
    ) {
        self.lookup = lookup
        self.fallback = fallback
    }

    /// Returns the resolved login shell, falling back to ``defaultFallback`` if the lookup yields nil.
    public func resolve() -> URL {
        lookup() ?? fallback
    }

    /// Native equivalent of `dscl . -read /Users/<user> UserShell`: queries `getpwuid` for the
    /// effective uid and reads `pw_shell`. Returns nil if the call fails or the shell field is empty.
    public static let directoryServicesLookup: @Sendable () -> URL? = {
        guard let entry = getpwuid(getuid()) else {
            return nil
        }
        guard let cString = entry.pointee.pw_shell else {
            return nil
        }
        let path = String(cString: cString)
        guard !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }
}
