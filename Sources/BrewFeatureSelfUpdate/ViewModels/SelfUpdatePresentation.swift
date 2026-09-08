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
        String(localized: "Upgrade Homebrew app", comment: "Self-update banner eyebrow")
    }

    var bannerTitle: String {
        String(
            localized: "A new version of the Homebrew app is available",
            comment: "Self-update banner title",
        )
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

    var upgradeActionTitle: String {
        guard let latest = latestVersionDisplay else {
            return String(
                localized: "Upgrade the Homebrew app",
                comment: "Self-update banner button when brew reports no version for the update",
            )
        }
        return String(
            localized: "Upgrade to \(latest)",
            comment: "Self-update banner button, e.g. \"Upgrade to v1.5.0\"",
        )
    }
}
