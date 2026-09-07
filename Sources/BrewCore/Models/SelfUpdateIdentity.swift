//
//  SelfUpdateIdentity.swift
//  BrewCore
//

import Foundation

/// How the app identifies *itself* to Homebrew. It ships as a cask, so its outdated state arrives through
/// the ordinary installed inventory — there is deliberately no second "ask brew what's current" path.
public enum SelfUpdateIdentity {
    public static let caskToken = "homebrew-app"

    public static let bundleIdentifier = "sh.brew.app"

    /// The cask's own `homepage`, so the fallback and what `brew info` reports agree.
    public static let homepageURL = URL(string: "https://github.com/Homebrew/BrewUI")!

    public static let displayCommand = "brew upgrade --cask \(caskToken)"
}
