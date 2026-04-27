//
//  InstalledPackagesRepositoryTestSupport.swift
//  BrewTests
//
//  Shared boundary fakes for `BrewInstalledPackagesRepository` / `InstalledViewModel` slice tests (`CONVENTIONS.md` — Testing).
//

@testable import Brew
import Foundation

// MARK: - Locator fakes

/// Injects `BrewLookupError.executableNotFound` through the real repository (no disk, no real `brew`).
struct MissingBrewExecutableLocator: BrewExecutableLocating {
    func findBrewExecutable() throws -> URL {
        throw BrewLookupError.executableNotFound
    }
}

// MARK: - Command runner

/// Per-invocation result for [`MockBrewCommandRunner`](MockBrewCommandRunner).
enum MockBrewCommandRunnerBehavior {
    case output(CommandOutput)
    case `throw`(Error)
}

/// Maps `brew` argument lists to output or thrown errors — fails fast on unexpected invocations.
struct MockBrewCommandRunner: BrewCommandRunning {
    private let behaviors: [[String]: MockBrewCommandRunnerBehavior]

    init(behaviors: [[String]: MockBrewCommandRunnerBehavior]) {
        self.behaviors = behaviors
    }

    /// Convenience: every invocation returns the given `CommandOutput`.
    init(responses: [[String]: CommandOutput]) {
        behaviors = responses.mapValues { .output($0) }
    }

    func run(executableURL _: URL, arguments: [String]) async throws -> CommandOutput {
        guard let behavior = behaviors[arguments] else {
            throw BrewCommandError.failed(exitCode: 99, stderr: "unmocked: \(arguments.joined(separator: " "))")
        }
        switch behavior {
        case let .output(out):
            return out
        case let .throw(error):
            throw error
        }
    }
}

// MARK: - Fixtures

enum InstalledPackagesTestSupport {
    /// Stable fake path passed to `commandRunner` when using `BrewExecutableLocator(overrideURL:)`.
    static let fakeBrewExecutableURL = URL(fileURLWithPath: "/fake/brew")

    /// Wired like production slice tests: default locator is [`fakeBrewExecutableURL`](fakeBrewExecutableURL).
    static func repository(
        commandRunner: BrewCommandRunning,
        locator: (any BrewExecutableLocating)? = nil,
    ) -> BrewInstalledPackagesRepository {
        let resolvedLocator = locator ?? BrewExecutableLocator(overrideURL: fakeBrewExecutableURL)
        return BrewInstalledPackagesRepository(commandRunner: commandRunner, locator: resolvedLocator)
    }

    // MARK: Localized copy (must match `InstalledViewModel.userMessage`)

    static func localizedBrewExecutableNotFoundMessage() -> String {
        String(
            localized: "Could not find Homebrew. Install it or ensure brew is in the default location.",
            comment: "Installed tab error when brew binary missing",
        )
    }

    static func localizedHomebrewCommandFailedMessage() -> String {
        String(
            localized: "Homebrew command failed.",
            comment: "Installed tab error generic brew failure",
        )
    }

    static func localizedGenericLoadFailureMessage() -> String {
        String(
            localized: "Something went wrong loading packages.",
            comment: "Installed tab generic error",
        )
    }

    /// Response for `brew info --installed --json=v2`.
    static func responsesInstalledInfoFailure(
        standardOutput: String = "",
        standardError: String,
        terminationStatus: Int32,
    ) -> [[String]: CommandOutput] {
        [
            ["info", "--installed", "--json=v2"]: CommandOutput(
                standardOutput: standardOutput,
                standardError: standardError,
                terminationStatus: terminationStatus,
            ),
        ]
    }

    /// Success response for `brew info --installed --json=v2`.
    static func installedInfoJSONResponse(
        standardOutput: String,
        terminationStatus: Int32 = 0,
        standardError: String = "",
    ) -> [[String]: CommandOutput] {
        [
            ["info", "--installed", "--json=v2"]: CommandOutput(
                standardOutput: standardOutput,
                standardError: standardError,
                terminationStatus: terminationStatus,
            ),
        ]
    }
}
