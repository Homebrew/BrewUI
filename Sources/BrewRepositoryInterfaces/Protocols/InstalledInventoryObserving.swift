//
//  InstalledInventoryObserving.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation
import Observation

/// Observable installed-inventory state plus its load lifecycle, for surfaces that render the whole list.
/// Refines `Observable` so SwiftUI tracks ``state`` reads through the existential.
@MainActor
public protocol InstalledInventoryObserving: Observable, Sendable {
    var state: LoadState<[InstalledBrewPackage], any Error> { get }

    /// Last failed refresh; nil once a fetch succeeds. `state` stays `.loaded` through a failed
    /// revalidation, so without this a surface cannot tell "nothing outdated" from "never found out".
    var refreshFailure: (any Error)? { get }

    /// Increments every time a fetch attempt settles — success, failure or cancellation. Busy
    /// presentation latches release when package data changes, but a failed refresh changes
    /// nothing, so surfaces watch this revision to release latches on fetches that settled
    /// without new data.
    var fetchRevision: Int { get }

    func load(forceRefresh: Bool) async
}

@MainActor
public extension InstalledInventoryObserving {
    func load() async {
        await load(forceRefresh: false)
    }
}
