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
/// `<login-shell> -l -i -c <exec script> <brew> <args...>`. The `-l` flag forces the shell's profile files
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
        try await run(executableURL: executableURL, arguments: arguments, console: nil)
    }

    public func run(
        executableURL: URL,
        arguments: [String],
        console: ConsoleOutputStream?,
    ) async throws -> CommandOutput {
        let shell = shellResolver.resolve()
        let shellCommand = Self.shellCommand(for: shell)
        let shellArguments = Self.shellArguments(executableURL: executableURL, arguments: arguments)
        // Forward `console` so the wrapped subprocess still streams + colours — the default protocol
        // implementation would drop it, silently disabling colour on the production login-shell path.
        return try await underlying.run(
            executableURL: shell,
            arguments: ["-l", "-i", "-c", shellCommand] + shellArguments,
            console: console,
        )
    }

    static func shellCommand(for shell: URL) -> String {
        if shell.lastPathComponent == "fish" {
            return "exec $argv"
        }
        return "exec \"$0\" \"$@\""
    }

    static func shellArguments(executableURL: URL, arguments: [String]) -> [String] {
        [executableURL.path] + arguments
    }
}
