//
//  BrewUITestScenario.swift
//  BrewUITests
//

import Foundation

/// The world a launch runs against: the fake `brew` serves `<scenario>/brew`, the stubbed `URLSession`
/// `<scenario>/http`. Both seams are data, so an error case is a fixture rather than different code.
enum BrewUITestScenario: String, CaseIterable {
    /// Nothing installed, empty catalogue, healthy doctor.
    case empty
    /// Two formulae and two casks installed; one formula is outdated.
    case installedBasic
    /// Enough formulae that `brew info` overruns a pipe buffer, which only a concurrent drain survives.
    case installedLarge
    /// `brew doctor` reports warnings and exits non-zero, which is data rather than failure.
    case doctorHasIssues
    /// Empty inventory with a populated catalogue, so Discover search has something to find.
    case discoverSearch
    /// The catalogue endpoint answers 500.
    case catalogueServerError
    /// `brew info --installed --json=v2` writes output that isn't JSON.
    case malformedInstalledInfo
    /// `brew install` writes to stderr and exits non-zero.
    case installFailure
    /// No `brew` executable can be resolved at all.
    case brewNotFound
    /// The app's own cask is installed and outdated, so real detection reports the upgrade. Answers no
    /// `brew upgrade`: the banner tests never press it.
    case selfUpgradeAvailable
    /// As above, plus the upgrade the helper really runs — `brew upgrade --cask homebrew-app` against the
    /// fake `brew`, from a process that outlives the app.
    case selfUpgradeRunsBrew
    /// The same, with an upgrade that exits non-zero: the app comes back saying so rather than silently.
    case selfUpgradeBrewFails
}
