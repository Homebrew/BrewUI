//
//  DiscoverPackagesRepository.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation
import Observation

/// App-scoped source of truth for Discover's trending list: one observable load state plus a cache-first
/// load, so any surface renders from a single fetch and the composition root can preload it at launch.
@MainActor
public protocol DiscoverPackagesRepository: Observable, Sendable {
    /// Trending packages: top formulae followed by top casks, each ranked by install count.
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
