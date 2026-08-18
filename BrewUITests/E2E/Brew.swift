//
//  Brew.swift
//  BrewUITests
//

import Foundation

/// Runs the machine's real `brew` from the *test* process, to arrange and clean up live-suite state.
///
/// This is a fixture actuator, not the code under test. The app reaches brew its own way — login
/// shell, `BrewExecutableLocator`, `BrewCommandService` — and that path is what the live tests act
/// through. Setup and cleanup deliberately take the short route instead: a broken arrange should read
/// as a broken fixture here, not as a missing row three screens into the flow under test.
nonisolated enum Brew {
    /// Homebrew's determinism switches, applied to every brew this suite causes to run — the one the
    /// app spawns (``BrewE2EApp`` puts them in the launch environment, and `BrewCommandService`
    /// inherits) and the ones below. `HOMEBREW_NO_AUTO_UPDATE` is the load-bearing one: without it an
    /// install can spend minutes updating the tap first, which reads as a hung test rather than a slow
    /// one. The rest keep a canary run from touching anything it doesn't own.
    static let determinismEnvironment = [
        "HOMEBREW_NO_AUTO_UPDATE": "1",
        "HOMEBREW_NO_ANALYTICS": "1",
        "HOMEBREW_NO_INSTALL_CLEANUP": "1",
        "HOMEBREW_NO_ENV_HINTS": "1",
    ]

    /// Same order as `BrewExecutableLocator`: Apple Silicon prefix, then Intel. Spelled again rather
    /// than imported because the test target links no product code, and because a fixture actuator
    /// resolving brew *differently* from the app is a difference worth being able to see.
    private static let candidatePaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]

    static func executableURL() throws -> URL {
        for path in candidatePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
            // `isExecutableFile(atPath:)` tests the symlink node rather than its destination, and both
            // prefixes ship `bin/brew` as a symlink — same fallback `BrewExecutableLocator` makes.
            let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath()
            if FileManager.default.isExecutableFile(atPath: resolved.path) {
                return resolved
            }
        }
        throw BrewFixtureError.brewNotFound(searched: candidatePaths)
    }

    /// Called from `setUp` so a runner without Homebrew fails by name, immediately. Left to the tests,
    /// the same machine fails several minutes later on an element query, saying nothing about why.
    static func requireAvailable() throws {
        _ = try executableURL()
    }

    /// Best-effort clean slate, called before and after every mutating test. Nothing here is
    /// actionable: uninstalling something that isn't installed exits non-zero — which is exactly what
    /// "already clean" looks like — and teardown runs where there is no test left to fail.
    static func forceUninstall(_ token: String) {
        _ = try? invoke(["uninstall", "--force", token])
    }

    /// Arrange step: anything but success is a broken fixture, so it throws with brew's own output
    /// attached instead of leaving the test to fail later on an absent row.
    static func run(_ arguments: String...) throws {
        let result = try invoke(arguments)
        guard result.status == 0 else {
            throw BrewFixtureError.commandFailed(
                command: arguments.joined(separator: " "),
                status: result.status,
                output: result.output,
            )
        }
    }

    private static func invoke(_ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = try executableURL()
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment
            .merging(determinismEnvironment) { _, determinism in determinism }
        // Null stdin, so a brew that decides to prompt gets EOF rather than waiting out the test's
        // whole time allowance.
        process.standardInput = FileHandle.nullDevice
        // One pipe for both streams, drained to EOF *before* waiting: an install writes far more than
        // a pipe buffer holds, and a child blocked writing into a full pipe never exits.
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw BrewFixtureError.couldNotRun(
                command: arguments.joined(separator: " "),
                underlying: error,
            )
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        // Only ever read by a human out of a failure message, so undecodable bytes say so rather than
        // being silently lost.
        let output = String(bytes: data, encoding: .utf8)
            ?? "(brew wrote \(data.count) bytes that are not valid UTF-8)"
        return (process.terminationStatus, output)
    }
}

/// Live-harness failure, kept distinct from any product error so it never reads as an app problem —
/// the same separation ``FakeBrewError`` makes for the deterministic suite.
enum BrewFixtureError: LocalizedError, CustomStringConvertible {
    case brewNotFound(searched: [String])
    case couldNotRun(command: String, underlying: any Error)
    case commandFailed(command: String, status: Int32, output: String)

    /// XCTest reports a thrown error's `localizedDescription`, which for a plain `Error` is the
    /// useless "operation couldn't be completed" boilerplate — these are thrown out of `setUp`, where
    /// that string is the only thing anyone sees.
    var errorDescription: String? {
        description
    }

    var description: String {
        switch self {
        case let .brewNotFound(searched):
            """
            The live suite needs Homebrew installed on this machine; no executable at \
            \(searched.joined(separator: " or ")). This suite is gated to Homebrew-equipped runners \
            (see BrewUITests/E2E/README.md) — it cannot be made to pass without one.
            """
        case let .couldNotRun(command, underlying):
            "Could not spawn “brew \(command)” for test setup: \(underlying)"
        case let .commandFailed(command, status, output):
            """
            Test setup command “brew \(command)” exited \(status). This is a fixture failure, not a \
            product one — the flow under test never ran. brew said:
            \(Self.tail(of: output))
            """
        }
    }

    /// The last lines only: a failed install prints its whole transcript, and the reason is at the end.
    private static func tail(of output: String, lines: Int = 20) -> String {
        let all = output.split(separator: "\n", omittingEmptySubsequences: false)
        return all.suffix(lines).joined(separator: "\n")
    }
}
