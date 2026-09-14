//
//  SelfUpgradeRunner.swift
//  BrewSelfUpgradeHelperCore
//

import BrewCLI
import BrewCore
import Foundation

/// Runs the upgrade through the same ``BrewCommandRunning`` the app runs every other brew command through.
/// Nobody is watching this one, so the transcript goes to a file and only the exit status is reported back.
public struct SelfUpgradeRunner: Sendable {
    public struct Outcome: Sendable, Equatable {
        public let succeeded: Bool
        public let detail: String

        public init(succeeded: Bool, detail: String) {
            self.succeeded = succeeded
            self.detail = detail
        }
    }

    private let commandRunner: any BrewCommandRunning
    private let transcriptSink: @Sendable (String) -> Void
    private let sleep: @Sendable (TimeInterval) async throws -> Void

    public init(
        commandRunner: any BrewCommandRunning,
        transcriptSink: @escaping @Sendable (String) -> Void = { _ in },
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) },
    ) {
        self.commandRunner = commandRunner
        self.transcriptSink = transcriptSink
        self.sleep = sleep
    }

    /// See ``SelfUpgradeHandoffSpec/usesLoginShell``.
    public init(
        usesLoginShell: Bool,
        transcriptSink: @escaping @Sendable (String) -> Void = { _ in },
    ) {
        self.init(
            commandRunner: usesLoginShell ? LoginShellBrewCommandRunner() : BrewCommandService(),
            transcriptSink: transcriptSink,
        )
    }

    public func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval,
    ) async -> Outcome {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            return Outcome(succeeded: false, detail: "no executable brew at \(executablePath)")
        }
        return await race(
            upgrade: { await upgrade(executablePath: executablePath, arguments: arguments, environment: environment) },
            timeout: timeout,
        )
    }

    // MARK: Upgrade

    private func upgrade(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
    ) async -> Outcome? {
        let sink = transcriptSink
        let options = BrewRunOptions(
            lineObserver: { line in sink(line.text) },
            output: .pipes(forceColor: false),
            environment: Self.pinnedEnvironment(adding: environment),
        )
        do {
            let output = try await commandRunner.run(
                executableURL: URL(fileURLWithPath: executablePath),
                arguments: arguments,
                options: options,
            )
            guard output.terminationStatus == 0 else {
                return Outcome(succeeded: false, detail: "brew exited \(output.terminationStatus)")
            }
            return Outcome(succeeded: true, detail: "brew \(arguments.joined(separator: " ")) succeeded")
        } catch is CancellationError {
            // The timeout won the race and owns the outcome.
            return nil
        } catch {
            return Outcome(succeeded: false, detail: "could not launch \(executablePath): \(error)")
        }
    }

    // MARK: Timeout

    /// Cancellation, not a signal to `brew`: a descendant left holding the output open would keep the
    /// drain — and so the helper — running forever. The loser is awaited so brew is gone before the relaunch.
    private func race(
        upgrade: @escaping @Sendable () async -> Outcome?,
        timeout: TimeInterval,
    ) async -> Outcome {
        let timedOut = Outcome(succeeded: false, detail: "brew did not finish within \(Int(timeout))s")
        let sleep = sleep
        return await withTaskGroup(of: Outcome?.self) { group in
            group.addTask { await upgrade() }
            group.addTask {
                guard await (try? sleep(timeout)) != nil else {
                    return nil
                }
                return timedOut
            }

            var outcome: Outcome?
            while let next = await group.next() {
                if let next {
                    outcome = next
                    break
                }
            }
            group.cancelAll()
            await group.waitForAll()
            return outcome ?? timedOut
        }
    }

    // MARK: Environment

    /// Colour is stripped because the transcript is a file; neither key changes what the upgrade does.
    static func pinnedEnvironment(adding overrides: [String: String]) -> [String: String] {
        var environment = [
            "HOMEBREW_NO_COLOR": "1",
            "HOMEBREW_NO_ENV_HINTS": "1",
        ]
        for (key, value) in overrides {
            environment[key] = value
        }
        return environment
    }
}
