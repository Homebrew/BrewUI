//
//  UninstallPackageItem.swift
//  Brew
//

import Foundation

/// Presentation mapping for uninstall actions shown in Installed package detail subviews.
struct UninstallPackageItem {
    private let package: InstalledBrewPackage
    private let blockingDependentCount: Int

    init(package: InstalledBrewPackage, blockingDependentCount: Int = 0) {
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
        return String(
            localized: "Blocked by installed dependents. Activate to see why.",
            comment: "Installed detail uninstall button accessibility hint when blocked",
        )
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
        return String(
            localized: "blocking uninstall",
            comment: "Installed detail Used by badge when dependents block uninstall",
        )
    }

    /// Leading sentence for the uninstall-blocked callout (bold in UI).
    var uninstallBlockedBannerLead: String? {
        guard isBlockedByDependents else {
            return nil
        }
        return String(
            localized: "Can't uninstall yet.",
            comment: "Installed detail uninstall blocked callout lead sentence",
        )
    }

    /// Body copy for the uninstall-blocked callout after the lead sentence.
    var uninstallBlockedBannerBody: String? {
        guard isBlockedByDependents else {
            return nil
        }
        let name = package.name
        if blockingDependentCount == 1 {
            return String(
                localized: "1 package above depends on \(name). Uninstall it first.",
                comment: "Installed detail uninstall blocked callout body for one dependent",
            )
        }
        let count = blockingDependentCount
        return String(
            localized: "\(count) packages above depend on \(name). Uninstall them first.",
            comment: "Installed detail uninstall blocked callout body for multiple dependents",
        )
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
        String(
            localized: "Uninstall",
            comment: "Installed detail uninstall button title",
        )
    }

    /// Confirmation title shown before uninstalling this package.
    var confirmationTitle: String {
        String(
            localized: "Uninstall \(package.name)?",
            comment: "Installed detail uninstall confirmation title; interpolated package name",
        )
    }

    /// Confirmation detail shown before uninstalling this package.
    var confirmationMessage: String {
        String(
            localized: "This will remove \(package.name) from this Mac using Homebrew.",
            comment: "Installed detail uninstall confirmation message; interpolated package name",
        )
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
