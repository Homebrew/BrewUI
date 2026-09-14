/*
 * [INPUT]: 依赖安装包数据与显式当前语言快照
 * [OUTPUT]: 派生可随语言重算的元信息或操作文案
 * [POS]: 安装展示值；命令字符串与业务判定不受语言影响
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  UninstallPackageItem.swift
//  Brew
//

import BrewCore
import BrewUIComponents
import Foundation

/// Presentation mapping for uninstall actions shown in Installed package detail subviews.
struct UninstallPackageItem {
    private let localization: AppLocalization
    private let package: InstalledBrewPackage
    private let blockingDependentCount: Int

    init(package: InstalledBrewPackage, blockingDependentCount: Int = 0, localization: AppLocalization = AppLocalization()) {
        self.localization = localization
        self.package = package
        self.blockingDependentCount = max(0, blockingDependentCount)
    }

    /// True when installed dependents prevent removing this package alone.
    var isBlockedByDependents: Bool {
        blockingDependentCount > 0
    }

    /// VoiceOver hint for the primary uninstall control when dependents block removal.
    var blockedPrimaryButtonAccessibilityHint: String? {
        guard isBlockedByDependents else {
            return nil
        }
        return localization.string("Blocked by installed dependents. Activate to see why.")
    }

    /// Lead and body for the uninstall-blocked callout, when shown.
    var blockedCalloutContent: UninstallBlockedCalloutContent? {
        guard let lead = uninstallBlockedBannerLead,
              let body = uninstallBlockedBannerBody
        else {
            return nil
        }
        return UninstallBlockedCalloutContent(lead: lead, body: body)
    }

    /// Badge beside the Used by heading when uninstall is blocked.
    var usedByBlockingBadgeTitle: String? {
        guard isBlockedByDependents else {
            return nil
        }
        return localization.string("blocking uninstall")
    }

    /// Leading sentence for the uninstall-blocked callout (bold in UI).
    var uninstallBlockedBannerLead: String? {
        guard isBlockedByDependents else {
            return nil
        }
        return localization.string("Can't uninstall yet.")
    }

    /// Body copy for the uninstall-blocked callout after the lead sentence.
    var uninstallBlockedBannerBody: String? {
        guard isBlockedByDependents else {
            return nil
        }
        let name = package.name
        if blockingDependentCount == 1 {
            return localization.string("1 package above depends on \(name). Uninstall it first.")
        }
        let count = blockingDependentCount
        return localization.string("\(count) packages above depend on \(name). Uninstall them first.")
    }

    /// Copyable Terminal command for uninstalling this package (`CONVENTIONS.md` — transparency).
    var displayCommand: String {
        switch package.kind {
        case .formula:
            "brew uninstall --formula \(package.name)"
        case .cask:
            "brew uninstall --cask \(package.name)"
        }
    }

    /// Primary uninstall button label.
    var primaryButtonTitle: String {
        localization.string("Uninstall")
    }

    /// Confirmation title shown before uninstalling this package.
    var confirmationTitle: String {
        localization.string("Uninstall \(package.name)?")
    }

    /// Confirmation detail shown before uninstalling this package.
    var confirmationMessage: String {
        localization.string("This will remove \(package.name) from this Mac using Homebrew.")
    }
}

/// Copy shown in the uninstall-blocked warning callout.
struct UninstallBlockedCalloutContent: Equatable {
    let lead: String
    let body: String
}

/// Result of activating the primary uninstall control in Installed detail.
enum UninstallPrimaryButtonAction: Equatable {
    case presentConfirmation
    case revealBlockedExplanation
}
