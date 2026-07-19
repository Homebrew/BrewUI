//
//  CrashReportEnvironment.swift
//  Brew
//

import Foundation

/// Build and OS details captured alongside a crash so a maintainer reading the
/// GitHub issue can tell which version produced it. `Sendable` so a signal
/// handler can read it from global state (see `CrashReportInstaller`).
public struct CrashReportEnvironment: Sendable, Equatable {
    public let appVersion: String
    public let buildNumber: String
    public let osVersion: String

    public init(appVersion: String, buildNumber: String, osVersion: String) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.osVersion = osVersion
    }

    /// Reads the running app's version and OS, falling back to `"unknown"` — a
    /// missing Info.plist key must never derail reporting an actual crash.
    public static func current(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
    ) -> CrashReportEnvironment {
        let info = bundle.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "unknown"
        return CrashReportEnvironment(
            appVersion: shortVersion,
            buildNumber: build,
            osVersion: processInfo.operatingSystemVersionString,
        )
    }
}
