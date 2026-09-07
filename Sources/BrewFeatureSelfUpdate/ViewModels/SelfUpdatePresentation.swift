//
//  SelfUpdatePresentation.swift
//  BrewFeatureSelfUpdate
//

import BrewCore
import Foundation

/// Copy for the self-update banner. The verb is "Upgrade" throughout, as it is for packages.
struct SelfUpdatePresentation {
    let status: SelfUpdateStatus

    var eyebrow: String {
        "Upgrade Homebrew app"
    }

    var bannerTitle: String {
        "A new version of Homebrew is available"
    }

    var runningVersionDisplay: String {
        "v\(status.runningVersion)"
    }

    var latestVersionDisplay: String? {
        status.latestVersion.map { "v\($0)" }
    }

    /// "v1.4.2 → v1.5.0", or just the running version when no latest is known.
    var versionSummary: String {
        guard let latest = latestVersionDisplay else {
            return runningVersionDisplay
        }
        return "\(runningVersionDisplay) → \(latest)"
    }

    /// Names the target version when known, e.g. "Upgrade to v1.5.0".
    var upgradeActionTitle: String {
        guard let latest = latestVersionDisplay else {
            return "Upgrade Homebrew"
        }
        return "Upgrade to \(latest)"
    }
}
