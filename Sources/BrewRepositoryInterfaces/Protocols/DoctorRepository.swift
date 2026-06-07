//
//  DoctorRepository.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation
import Observation

/// App-scoped, observable source of truth for `brew doctor` diagnostics.
///
/// This is the diagnostics *read* path — it does not mutate Homebrew. Implementations may still route
/// `brew doctor` through the command center so output appears in the app console. It is long-lived so
/// the parsed report survives navigating away from and back to the Doctor tab; `load()` refreshes in the
/// background, keeping the prior report on screen while it runs (stale-while-revalidate).
/// Refines `Observable` so SwiftUI tracks ``state`` / ``isRefreshing`` reads through the existential.
@MainActor
public protocol DoctorRepository: Observable, Sendable {
    /// Latest parsed `brew doctor` outcome. `.loading` only before the first successful load; afterwards the
    /// prior `.loaded` report stays put across refreshes.
    var state: LoadState<DoctorReport, any Error> { get }

    /// `true` while a re-check runs and a prior report is already on screen — drives a subtle "checking" hint
    /// without blanking the content.
    var isRefreshing: Bool { get }

    /// Runs `brew doctor` and updates ``state``. Coalesces concurrent calls; keeps stale data visible while running.
    func load() async
}
