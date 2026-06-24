//
//  LoginShellBrewCommandRunner.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Decorates a ``BrewCommandRunning`` so every brew invocation is executed inside the user's
/// login + interactive shell. Produces parity with what the user sees in Terminal — `brew config`
/// and `brew doctor` are the strict acceptance bar; every other invocation inherits the same
/// environment for free.
///
/// The wrapper rewrites `run(executableURL: brew, arguments: [...])` into
/// `<login-shell> -l -i -c "<brew> <quoted args>"`. The `-l` flag forces the shell's profile files
/// (`.zprofile`, `.bash_profile`) to load — that is where Homebrew installs `brew shellenv`. The
/// `-i` flag additionally sources interactive rc files (`.zshrc`, `.bashrc`) so users who put
/// their brew setup in those files also get parity; the tradeoff is that interactive rc files may
/// print banners or expect a TTY, which we accept as the cost of exact-Terminal parity.
public struct LoginShellBrewCommandRunner: BrewCommandRunning {
    private let underlying: any BrewCommandRunning
    private let shellResolver: LoginShellResolver

    public init(
        underlying: any BrewCommandRunning = BrewCommandService(),
        shellResolver: LoginShellResolver = LoginShellResolver(),
    ) {
        self.underlying = underlying
        self.shellResolver = shellResolver
    }

    public func run(executableURL: URL, arguments: [String]) async throws -> CommandOutput {
        let shell = shellResolver.resolve()
        let command = Self.shellCommand(executableURL: executableURL, arguments: arguments)
        return try await underlying.run(
            executableURL: shell,
            arguments: ["-l", "-i", "-c", command],
        )
    }

    /// Joins the brew executable path and its arguments into a single shell-safe command string,
    /// suitable for passing as the argument to `sh -c` / `zsh -c`. Each token is wrapped in single
    /// quotes; any embedded single-quote is escaped as `'\''` (POSIX-portable). This keeps package
    /// names and flags that contain spaces, `$`, backticks, or other metacharacters intact.
    static func shellCommand(executableURL: URL, arguments: [String]) -> String {
        let tokens = [executableURL.path] + arguments
        return tokens.map(singleQuoted).joined(separator: " ")
    }

    static func singleQuoted(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
