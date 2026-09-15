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
///
/// The exec script is written for POSIX shells.
/// Fish has its own fallback. Other shells fall back to /bin/zsh
public struct LoginShellBrewCommandRunner: BrewCommandRunning {
    private let underlying: any BrewCommandRunning
    private let shellResolver: LoginShellResolver
    private let makeMarker: @Sendable () -> String

    public init(
        underlying: any BrewCommandRunning = BrewCommandService(),
        shellResolver: LoginShellResolver = LoginShellResolver(),
        makeMarker: @escaping @Sendable () -> String = { UUID().uuidString },
    ) {
        self.underlying = underlying
        self.shellResolver = shellResolver
        self.makeMarker = makeMarker
    }

    public func run(
        executableURL: URL,
        arguments: [String],
        options: BrewRunOptions,
    ) async throws -> CommandOutput {
        var options = options
        let shell = Self.supportedShell(for: shellResolver.resolve())
        let marker = makeMarker()
        let shellCommand = Self.shellCommand(for: shell, marker: marker, output: options.output)
        let shellArguments = Self.shellArguments(executableURL: executableURL, arguments: arguments)

        if let lineObserver = options.lineObserver {
            let gate = LoginShellStartupGate(marker: marker)
            options.lineObserver = { line in
                if let admitted = gate.admit(line) {
                    lineObserver(admitted)
                }
            }
        }

        // Forward `options` so the wrapped subprocess still streams + colours — the default protocol
        // implementation would drop it, silently disabling colour on the production login-shell path.
        let output = try await underlying.run(
            executableURL: shell,
            arguments: ["-l", "-i", "-c", shellCommand] + shellArguments,
            options: options,
        )
        return CommandOutput(
            standardOutput: Self.removingStartupNoise(from: output.standardOutput, upTo: marker),
            standardError: Self.removingStartupNoise(from: output.standardError, upTo: marker),
            terminationStatus: output.terminationStatus,
        )
    }

    /// Printed to the streams the child will actually use, right after `-l -i` startup and before
    /// `exec`, so ``removingStartupNoise(from:upTo:)`` has an exact line to cut rc-file noise at.
    static func shellCommand(for shell: URL, marker: String, output: BrewRunOptions.OutputChannel) -> String {
        let announce = switch output {
        case .pipes:
            "printf '%s\\n' '\(marker)' 1>&2; printf '%s\\n' '\(marker)'; "
        case .pseudoTerminal:
            "printf '%s\\n' '\(marker)'; "
        }
        let exec = shell.lastPathComponent == "fish" ? "exec $argv" : "exec \"$0\" \"$@\""
        return announce + exec
    }

    /// Shells whose `-c` script the runner can generate: POSIX `sh`-family shells plus fish.
    static let supportedShellNames: Set<String> = ["sh", "bash", "zsh", "ksh", "dash", "fish"]

    /// Returns `shell` when ``shellCommand(for:marker:output:)`` can target it, otherwise the
    /// default POSIX-compatible fallback.
    static func supportedShell(for shell: URL) -> URL {
        supportedShellNames.contains(shell.lastPathComponent) ? shell : LoginShellResolver.defaultFallback
    }

    static func shellArguments(executableURL: URL, arguments: [String]) -> [String] {
        [executableURL.path] + arguments
    }

    static func removingStartupNoise(from text: String, upTo marker: String) -> String {
        guard let markerRange = text.range(of: marker) else {
            return text
        }
        let remainder = text[markerRange.upperBound...]
        guard let newline = remainder.firstIndex(of: "\n") else {
            return String(remainder)
        }
        return String(remainder[remainder.index(after: newline)...])
    }
}

/// Drops every live console line up to and including the login-shell startup marker, so streamed
/// output skips the same rc-file noise ``LoginShellBrewCommandRunner`` strips from the buffered result.
// swiftlint:disable:next unchecked_sendable
private final class LoginShellStartupGate: @unchecked Sendable {
    private let lock = NSLock()
    private let marker: String
    private var admittingStdout = false
    private var admittingStderr = false

    init(marker: String) {
        self.marker = marker
    }

    func admit(_ line: BrewCommandOutputLine) -> BrewCommandOutputLine? {
        lock.lock()
        defer { lock.unlock() }
        let admitting = switch line.stream {
        case .stdout:
            admittingStdout
        case .stderr:
            admittingStderr
        }
        if admitting {
            return line
        }
        if line.text == marker {
            switch line.stream {
            case .stdout:
                admittingStdout = true
            case .stderr:
                admittingStderr = true
            }
        }
        return nil
    }
}
