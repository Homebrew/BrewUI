//
//  SecurityAdvisoryRepository.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation
import Observation

/// App-scoped, observable source of truth for `brew vulns` security advisories.
///
/// A read path that does not mutate Homebrew. A scan sends each installed formula's upstream repository
/// and version to OSV.dev, so implementations only scan when asked, never at launch. The parsed report
/// survives navigating away from the Security tab; a refresh keeps the prior report on screen.
/// Refines `Observable` so SwiftUI tracks ``state`` / ``isRefreshing`` reads through the existential.
@MainActor
public protocol SecurityAdvisoryRepository: Observable, Sendable {
    /// Latest scan outcome. `.loading` only before the first successful scan; afterwards the prior
    /// `.loaded` report stays put across refreshes.
    var state: LoadState<SecurityAdvisoryReport, any Error> { get }

    /// When the report on screen was produced. A failed scan leaves this alone.
    var scannedAt: Date? { get }

    /// `true` while a re-scan runs and a prior report is already on screen.
    var isRefreshing: Bool { get }

    /// Runs `brew vulns` and updates ``state``. Coalesces concurrent calls and keeps stale data visible;
    /// a report younger than the refresh interval, taken against the same installed formulae, is kept
    /// as-is unless `forceRefresh`.
    func load(forceRefresh: Bool) async
}
