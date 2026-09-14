/*
 * [INPUT]: 依赖自升级状态与当前语言快照
 * [OUTPUT]: 派生自升级横幅、按钮及结果提示
 * [POS]: 自升级展示边界，不修改升级协调器或重启流程
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  SelfUpgradePresentation.swift
//  BrewFeatureSelfUpgrade
//

import BrewCore
import BrewUIComponents
import Foundation

/// Copy for the alert the app shows on the launch after an upgrade attempt. One value carries both
/// outcomes because SwiftUI presents only the first `.alert` attached to a view.
public struct SelfUpgradeOutcomePresentation {
    private let localization: AppLocalization
    public let outcome: SelfUpgradeOutcome

    public init(outcome: SelfUpgradeOutcome, localization: AppLocalization = AppLocalization()) {
        self.outcome = outcome
        self.localization = localization
    }

    public var title: String {
        switch outcome {
        case .succeeded:
            localization.string("The Homebrew app is up to date")
        case .failed:
            localization.string("The Homebrew app wasn’t upgraded")
        }
    }

    public var message: String {
        switch outcome {
        case .succeeded:
            localization.string("The Homebrew app has been upgraded to the latest version.")
        case .failed:
            localization.string("""
            The upgrade didn’t finish, so this is still the previous version. You can try again from \
            the banner above your packages.
            """)
        }
    }
}

/// Copy for the self-upgrade banner.
struct SelfUpgradePresentation {
    let status: SelfUpgradeStatus
    private let localization: AppLocalization

    init(status: SelfUpgradeStatus, localization: AppLocalization = AppLocalization()) {
        self.status = status
        self.localization = localization
    }

    var eyebrow: String {
        localization.string("Upgrade Homebrew app")
    }

    var bannerTitle: String {
        localization.string("A new version of the Homebrew app is available")
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
            return localization.string("Upgrade the Homebrew app")
        }
        return localization.string("Upgrade to \(latest)")
    }
}
