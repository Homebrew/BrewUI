//
//  LoginShellResolver.swift
//  BrewCLI
//

import Darwin
import Foundation

/// Resolves the current user's login shell from Directory Services (`getpwuid_r` reads the same
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

    /// Native equivalent of `dscl . -read /Users/<user> UserShell`, using the thread-safe
    /// `getpwuid_r`. Returns nil if the lookup fails or the path isn't a trustworthy absolute path.
    public static let directoryServicesLookup: @Sendable () -> URL? = {
        guard let path = resolveLoginShellPath() else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// Does the actual `getpwuid_r` lookup.
    private static func resolveLoginShellPath() -> String? {
        var pwd = passwd()
        var result: UnsafeMutablePointer<passwd>?

        let suggestedSize = sysconf(_SC_GETPW_R_SIZE_MAX)
        let bufferSize = suggestedSize > 0 ? Int(suggestedSize) : 16384

        var buffer = [CChar](repeating: 0, count: bufferSize)

        let rc: Int32 = buffer.withUnsafeMutableBufferPointer { buf in
            guard let baseAddress = buf.baseAddress else { return EINVAL }
            return getpwuid_r(getuid(), &pwd, baseAddress, buf.count, &result)
        }

        guard rc == 0, let entry = result else { return nil }
        guard let cString = entry.pointee.pw_shell else { return nil }

        let path = String(cString: cString)

        guard path.hasPrefix("/") else { return nil }

        return path
    }
}
