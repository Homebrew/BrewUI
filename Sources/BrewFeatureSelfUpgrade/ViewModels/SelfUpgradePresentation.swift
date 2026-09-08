//
//  SelfUpgradePresentation.swift
//  BrewFeatureSelfUpgrade
//

import BrewCore
import Foundation

/// Copy for the alert the app shows on the launch after an upgrade attempt.
///
/// Both outcomes read from one value because SwiftUI presents only the first `.alert` attached to a view:
/// two of them left the failure alert permanently unreachable, so the app relaunched at the old version
/// saying nothing.
public struct SelfUpgradeOutcomePresentation {
    public let outcome: SelfUpgradeOutcome

    public init(outcome: SelfUpgradeOutcome) {
        self.outcome = outcome
    }

    public var title: String {
        switch outcome {
        case .succeeded:
            String(
                localized: "The Homebrew app is up to date",
                comment: "Alert title on the launch after a successful self-upgrade",
            )
        case .failed:
            String(
                localized: "The Homebrew app wasn’t upgraded",
                comment: "Alert title on the launch after a self-upgrade that failed",
            )
        }
    }

    public var message: String {
        switch outcome {
        case .succeeded:
            String(
                localized: "The Homebrew app has been upgraded to the latest version.",
                comment: "Alert body on the launch after a successful self-upgrade",
            )
        case .failed:
            String(
                localized: """
                The upgrade didn’t finish, so this is still the previous version. You can try again from \
                the banner above your packages.
                """,
                comment: "Alert body on the launch after a self-upgrade that failed",
            )
        }
    }
}

/// Copy for the self-upgrade banner. The verb is "Upgrade" throughout, as it is for packages.
struct SelfUpgradePresentation {
    let status: SelfUpgradeStatus

    var eyebrow: String {
        String(localized: "Upgrade Homebrew app", comment: "Self-upgrade banner eyebrow")
    }

    var bannerTitle: String {
        String(
            localized: "A new version of the Homebrew app is available",
            comment: "Self-upgrade banner title",
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
                comment: "Self-upgrade banner button when brew reports no version for the upgrade",
            )
        }
        return String(
            localized: "Upgrade to \(latest)",
            comment: "Self-upgrade banner button, e.g. \"Upgrade to v1.5.0\"",
        )
    }
}
