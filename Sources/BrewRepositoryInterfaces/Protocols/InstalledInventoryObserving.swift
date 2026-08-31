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

    /// The error from the most recent revalidation that failed while cached inventory stayed on
    /// screen; nil once a fetch succeeds. `state` cannot carry this — it deliberately stays `.loaded`
    /// so the cached list survives a failed refresh — yet without it a surface cannot tell "nothing is
    /// outdated" from "the outdated check never completed".
    var refreshFailure: (any Error)? { get }

    func load(forceRefresh: Bool) async
}

@MainActor
public extension InstalledInventoryObserving {
    func load() async {
        await load(forceRefresh: false)
    }
}
