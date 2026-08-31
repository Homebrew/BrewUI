//
//  CommandRunnerDoubles.swift
//  BrewServicesTestSupport
//

import BrewCore
import Foundation

/// Injects `BrewLookupError.executableNotFound` through the real repository (no disk, no real `brew`).
public struct MissingBrewExecutableLocator: BrewExecutableLocating {
    public init() {}

    public func findBrewExecutable() throws -> URL {
        throw BrewLookupError.executableNotFound
    }
}

/// Fixed answer for ``HomebrewEnvironmentReading``, so a test can pin which package-data source
/// brew is configured to use without running `brew config`.
public struct StubHomebrewEnvironment: HomebrewEnvironmentReading {
    private let installFromAPIDisabled: Bool

    public init(installFromAPIDisabled: Bool) {
        self.installFromAPIDisabled = installFromAPIDisabled
    }

    public func isInstallFromAPIDisabled() async -> Bool {
        installFromAPIDisabled
    }
}

/// Per-invocation result for ``MockBrewCommandRunner``.
public enum MockBrewCommandRunnerBehavior: Sendable {
    case output(CommandOutput)
    case `throw`(any Error & Sendable)
}

/// Maps `brew` argument lists to output or thrown errors — fails fast on unexpected invocations.
public struct MockBrewCommandRunner: BrewCommandRunning {
    private let behaviors: [[String]: MockBrewCommandRunnerBehavior]

    public init(behaviors: [[String]: MockBrewCommandRunnerBehavior]) {
        self.behaviors = behaviors
    }

    /// Convenience: every invocation returns the given `CommandOutput`.
    public init(responses: [[String]: CommandOutput]) {
        behaviors = responses.mapValues { .output($0) }
    }

    public func run(
        executableURL _: URL,
        arguments: [String],
        options _: BrewRunOptions,
    ) async throws -> CommandOutput {
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

/// Returns a different `brew info` JSON payload per invocation (last payload repeats), for two-load tests.
public actor QueuedBrewInfoRunner: BrewCommandRunning {
    private let outputs: [CommandOutput]
    private var index = 0

    public init(infoJSON: [String]) {
        outputs = infoJSON.map {
            CommandOutput(standardOutput: $0, standardError: "", terminationStatus: 0)
        }
    }

    public func run(
        executableURL _: URL,
        arguments _: [String],
        options _: BrewRunOptions,
    ) async throws -> CommandOutput {
        let output = outputs[min(index, outputs.count - 1)]
        if index < outputs.count - 1 {
            index += 1
        }
        return output
    }
}
