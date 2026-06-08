//
//  ConfigRepository.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

/// App-scoped, cached source of truth for `brew config` + the effective `HOMEBREW_*` process
/// environment. Long-lived `@Observable` so any surface in the app reads from one snapshot fetched
/// once per launch; refreshes happen on demand (`forceRefresh: true`) without dropping the cached
/// value visible to the UI (`[[project-brewui-product-intent]]`).
@MainActor
public protocol ConfigRepository: Sendable {
    var state: LoadState<BrewConfigSnapshot, any Error> { get }

    /// Cache-first by default. Refetches when forced, when the cache has been ``invalidate()``d, or
    /// when no value has loaded yet. A refetch keeps any existing `.loaded` value on screen while the
    /// fetch runs, only replacing it on success.
    func load(forceRefresh: Bool) async

    /// Marks the cached state as needing revalidation on the next `load()` call. The cached value
    /// stays visible — only the freshness flag flips. Used by the app's scene-phase observer to
    /// defer the refetch until the user returns to the Configuration tab.
    func invalidate()
}
