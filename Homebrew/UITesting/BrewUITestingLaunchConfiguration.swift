/*
 * [INPUT]: 依赖共享测试契约、进程参数和 Debug fixture bundle 的显式启动标记
 * [OUTPUT]: 仅在明确的测试启动中选择隔离的 CLI 与 HTTP 载荷
 * [POS]: App 的测试边界；发行版只接受原有 XCTest 参数，不读取 bundle 测试标记
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
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

    static func current(processInfo: ProcessInfo = .processInfo, bundle: Bundle = .main) -> BrewUITestingLaunchConfiguration? {
        let environment = processInfo.environment
        var isUITesting = processInfo.arguments.contains(BrewUITestingEnvironmentKey.launchArgument)
        #if DEBUG
            // CUA 在后台通过 Launch Services 启动 app，无法传 XCTest 参数；只有专用 fixture 副本显式设置此标记。
            isUITesting = isUITesting || (
                bundle.object(forInfoDictionaryKey: "BrewUITesting") as? Bool == true
                    && environment[BrewUITestingEnvironmentKey.scenario] != nil
                    && environment[BrewUITestingEnvironmentKey.payload] != nil
            )
        #endif
        guard isUITesting else {
            return nil
        }
        return BrewUITestingLaunchConfiguration(
            scenario: environment[BrewUITestingEnvironmentKey.scenario],
            payload: environment[BrewUITestingEnvironmentKey.payload],
            fixturesRootURL: environment[BrewUITestingEnvironmentKey.fixturesRoot]
                .map { URL(fileURLWithPath: $0) },
        )
    }
}
