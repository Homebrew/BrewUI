//
//  SelfUpgradeIdentity.swift
//  BrewCore
//

import Foundation

/// How the app identifies *itself* to Homebrew. It ships as a cask, so its outdated state arrives through
/// the ordinary installed inventory — there is deliberately no second "ask brew what's current" path.
public enum SelfUpgradeIdentity {
    public static let caskToken = "homebrew-app"

    public static let bundleIdentifier = "sh.brew.app"

    /// The cask's own `homepage`, so the fallback and what `brew info` reports agree.
    public static let homepageURL = URL(string: "https://github.com/Homebrew/BrewUI")!

    public static let displayCommand = "brew upgrade --cask \(caskToken)"

    public static let packageID = HomebrewPackageID.cask(token: caskToken)
}

public extension InstalledBrewPackage {
    /// Left out of every list, count and batch: an in-process `brew upgrade` would replace the running bundle.
    var isTheAppsOwnCask: Bool {
        kind == .cask && name == SelfUpgradeIdentity.caskToken
    }
}
