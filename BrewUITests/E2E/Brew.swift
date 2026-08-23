//
//  Brew.swift
//  BrewUITests
//

import Foundation

/// Arranges and cleans up live-suite state through the machine's real `brew`, never as the code under
/// test: the tests themselves act through the app's own path to brew.
nonisolated enum Brew {
    /// Applied to every brew this suite runs, the app's included. Without `HOMEBREW_NO_AUTO_UPDATE` an
    /// install can spend minutes updating the tap first, which reads as a hung test.
    static let determinismEnvironment = [
        "HOMEBREW_NO_AUTO_UPDATE": "1",
        "HOMEBREW_NO_ANALYTICS": "1",
        "HOMEBREW_NO_INSTALL_CLEANUP": "1",
        "HOMEBREW_NO_ENV_HINTS": "1",
    ]

    /// Mirrors `BrewExecutableLocator`, spelled again because the test target links no product code.
    private static let candidatePaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]

    static func executableURL() throws -> URL {
        for path in candidatePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
            // `isExecutableFile(atPath:)` tests the symlink node, and `bin/brew` is one.
            let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath()
            if FileManager.default.isExecutableFile(atPath: resolved.path) {
                return resolved
            }
        }
        throw BrewFixtureError.brewNotFound(searched: candidatePaths)
    }

    /// Called from `setUp`, so a machine without Homebrew fails by name rather than on an element query.
    static func requireAvailable() throws {
        _ = try executableURL()
    }

    /// Best effort: uninstalling what isn't installed exits non-zero, which is "already clean".
    static func forceUninstall(_ token: String) {
        _ = try? invoke(["uninstall", "--force", token])
    }

    /// Arrange step, throwing with brew's own output rather than failing later on an absent row.
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
        // A brew that decides to prompt gets EOF rather than the test's whole time allowance.
        process.standardInput = FileHandle.nullDevice
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

        // Drained before waiting: a child blocked writing into a full pipe never exits.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(bytes: data, encoding: .utf8)
            ?? "(brew wrote \(data.count) bytes that are not valid UTF-8)"
        return (process.terminationStatus, output)
    }
}

/// Live-harness failure, kept distinct from any product error so it never reads as an app problem.
enum BrewFixtureError: LocalizedError, CustomStringConvertible {
    case brewNotFound(searched: [String])
    case couldNotRun(command: String, underlying: any Error)
    case commandFailed(command: String, status: Int32, output: String)

    /// These are thrown out of `setUp`, where XCTest reports `localizedDescription` and nothing else.
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

    /// A failed install prints its whole transcript; the reason is at the end.
    private static func tail(of output: String, lines: Int = 20) -> String {
        let all = output.split(separator: "\n", omittingEmptySubsequences: false)
        return all.suffix(lines).joined(separator: "\n")
    }
}
