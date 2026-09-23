//
//  ZshBrewCommandRunner.swift
//  BrewCLI
//

import BrewCore
import Foundation
import Synchronization

/// Runs brew through system zsh with an explicit environment. Homebrew loads user settings from `brew.env`.
public struct ZshBrewCommandRunner: BrewCommandRunning {
    private let underlying: any BrewCommandRunning

    public init(underlying: any BrewCommandRunning = BrewCommandService()) {
        self.underlying = underlying
    }

    public func run(
        executableURL: URL,
        arguments: [String],
        options: BrewRunOptions,
    ) async throws -> CommandOutput {
        var environment = [
            "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
            "USER": NSUserName(),
            "LOGNAME": NSUserName(),
            "TMPDIR": FileManager.default.temporaryDirectory.path,
            "LANG": "en_US.UTF-8",
        ]
        switch options.output {
        case .pseudoTerminal:
            environment["TERM"] = "xterm-256color"
            fallthrough
        case .pipes(forceColor: true):
            // Also covers a pseudo-terminal falling back to pipes.
            environment["HOMEBREW_COLOR"] = "1"
            environment["CLICOLOR_FORCE"] = "1"
        case .pipes(forceColor: false):
            break
        }
        environment.merge(options.environment) { _, override in override }
        environment["SHELL"] = "/bin/zsh"
        let binDirectory = executableURL.deletingLastPathComponent()
        environment["PATH"] = binDirectory.path + ":"
            + binDirectory.deletingLastPathComponent().appendingPathComponent("sbin").path + ":/usr/bin:/bin"
        let assignments = environment.map { "\($0.key)=\($0.value)" }
        let startup = ZshStartupOutput()
        var wrappedOptions = options
        if let observer = options.lineObserver {
            wrappedOptions.lineObserver = { line in
                if startup.admit(line) { observer(line) }
            }
        }
        defer { startup.pendingLines.forEach { options.lineObserver?($0) } }

        // /etc/zshenv always runs. Mark its output and clear its exports, keeping argv literal.
        // Check the actual terminal so a fallback to pipes gets a marker on each stream.
        var output = try await underlying.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["-i"] + assignments + [
                "/bin/zsh", "--no-rcs", "--no-global-rcs", "-c",
                "[[ -t 1 ]] || printf '\\n%s\\n' \"$0\" >&2; printf '\\n%s\\n' \"$0\"; exec /usr/bin/env -i \"$@\"",
                startup.marker,
            ] + assignments + [executableURL.path] + arguments,
            options: wrappedOptions,
        )
        output.standardOutput = startup.removingBanner(from: output.standardOutput)
        output.standardError = startup.removingBanner(from: output.standardError)
        return output
    }
}

private final class ZshStartupOutput: Sendable {
    let marker = UUID().uuidString
    private let state = Mutex<(started: [BrewCommandOutputLine.Stream], pending: [BrewCommandOutputLine])>(([], []))

    /// Retain diagnostics if startup exits before the marker, including on cancellation.
    var pendingLines: [BrewCommandOutputLine] {
        state.withLock { $0.pending }
    }

    func admit(_ line: BrewCommandOutputLine) -> Bool {
        state.withLock { state in
            if state.started.contains(line.stream) {
                return true
            }
            if line.isComplete, line.text == marker {
                state.started.append(line.stream)
                state.pending.removeAll { $0.stream == line.stream }
            } else {
                state.pending.append(line)
            }
            return false
        }
    }

    func removingBanner(from text: String) -> String {
        guard let range = text.range(of: "\n\(marker)\n") else {
            return text
        }
        return String(text[range.upperBound...])
    }
}
