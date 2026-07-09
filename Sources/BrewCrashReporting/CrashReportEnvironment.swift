//
//  CrashReportEnvironment.swift
//  Brew
//

import Foundation

/// The static environment details captured alongside a crash so a maintainer
/// reading the resulting GitHub issue can tell which build and OS produced it.
///
/// Kept deliberately small and `Sendable` so it can be stashed in the global
/// state a signal handler reads (see `CrashReportInstaller`).
public struct CrashReportEnvironment: Sendable, Equatable {
    public let appVersion: String
    public let buildNumber: String
    public let osVersion: String

    public init(appVersion: String, buildNumber: String, osVersion: String) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.osVersion = osVersion
    }

    /// Reads the running app's version + OS from `bundle` / `ProcessInfo`.
    ///
    /// Falls back to `"unknown"` rather than crashing while *reporting* a crash —
    /// a missing Info.plist key must never take precedence over the real report.
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
