//
//  BrewUITestScenario.swift
//  BrewUITests
//

import Foundation

/// The world a UI-test launch runs against: one fixture set, read by both seams once the app has
/// installed it — the fake `brew` serves `<scenario>/brew`, the stubbed `URLSession` `<scenario>/http`.
///
/// Because both seams are data, an error case is a different fixture rather than different code: a 500
/// is a `.status` file, a failing install an `.exitcode` file.
enum BrewUITestScenario: String, CaseIterable {
    /// Nothing installed, empty catalogue, healthy doctor.
    case empty
    /// Two formulae and two casks installed; one formula is outdated.
    case installedBasic
    /// Enough formulae that `brew info` overruns a pipe buffer, so the runner's concurrent drain is
    /// what keeps the subprocess from deadlocking.
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
}
