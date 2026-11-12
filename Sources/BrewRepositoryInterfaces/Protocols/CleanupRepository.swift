//
//  CleanupRepository.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation
import Observation

/// App-scoped, observable preview of what `brew cleanup` would remove.
///
/// This is the *read* path: it runs `brew cleanup --dry-run` directly, outside the console, and never
/// removes anything itself. It is long-lived so reopening the Clean Up sheet shows the last report while it
/// checks again. Refines `Observable` so SwiftUI tracks reads through
/// the existential.
@MainActor
public protocol CleanupRepository: Observable, Sendable {
    /// `.loading` until a preview for the requested option has loaded. A refresh for the same option keeps
    /// the prior report on screen; a different option replaces it, since the old one no longer applies.
    var state: LoadState<CleanupReport, any Error> { get }

    /// Set when a refresh fails while a prior report stays on screen; cleared by the next success.
    var refreshFailure: (any Error)? { get }

    /// `true` while a refresh runs with a prior report already on screen.
    var isRefreshing: Bool { get }

    /// Runs `brew cleanup --dry-run`, adding `--prune=all` when `pruneAll`, and updates ``state``.
    /// Concurrent calls for the same option share one run.
    func load(pruneAll: Bool) async
}
