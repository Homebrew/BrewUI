//
//  DiscoverPackagesRepository.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation
import Observation

/// App-scoped source of truth for Discover's trending list: an observable load state plus a cache-first
/// load. A single observable so any surface renders from one fetch and the composition root can preload
/// it at launch. The default traps — the composition root must inject a live instance.
@MainActor
public protocol DiscoverPackagesRepository: Observable, Sendable {
    /// Trending packages — top formulae followed by top casks — in the backend's install-rank order.
    var state: LoadState<[DiscoveryBrewPackage], any Error> { get }

    /// Cache-first by default: fresh in-memory data returns instantly; stale data revalidates while the
    /// prior list stays on screen; an empty/failed state fetches. `forceRefresh` always fetches.
    func load(forceRefresh: Bool) async
}

@MainActor
public extension DiscoverPackagesRepository {
    func load() async {
        await load(forceRefresh: false)
    }
}
