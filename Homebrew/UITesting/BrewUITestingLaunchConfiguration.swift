//
//  BrewUITestingLaunchConfiguration.swift
//  Homebrew
//

import BrewUITestContract
import Foundation

/// The launch contract between the UI-test target and ``BrewApp``'s composition root.
/// ``current(processInfo:)`` returns `nil` outside a UI test, so being in test mode is one check
/// rather than a flag threaded through the app.
///
/// `nonisolated` because ``BrewUITestingStubURLProtocol`` reads it from `URLSession` loading threads.
nonisolated struct BrewUITestingLaunchConfiguration {
    let scenario: String?
    let payload: String?
    let fixturesRootURL: URL?

    /// `nil` until the fixture tree is installed.
    var httpFixturesURL: URL? {
        guard let fixturesRootURL, let scenario else {
            return nil
        }
        return fixturesRootURL
            .appendingPathComponent(scenario, isDirectory: true)
            .appendingPathComponent("http", isDirectory: true)
    }

    static func current(processInfo: ProcessInfo = .processInfo) -> BrewUITestingLaunchConfiguration? {
        guard processInfo.arguments.contains(BrewUITestingEnvironmentKey.launchArgument) else {
            return nil
        }
        let environment = processInfo.environment
        return BrewUITestingLaunchConfiguration(
            scenario: environment[BrewUITestingEnvironmentKey.scenario],
            payload: environment[BrewUITestingEnvironmentKey.payload],
            fixturesRootURL: environment[BrewUITestingEnvironmentKey.fixturesRoot]
                .map { URL(fileURLWithPath: $0) },
        )
    }
}
