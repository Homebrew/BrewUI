//
//  EnvFileRepository.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

/// App-scoped, cached read + atomic write of Homebrew's user-level `brew.env`. The cached `state`
/// stays visible across tab switches and is refreshed silently on `forceRefresh: true` so the editor
/// keeps showing stale content while a background revalidation runs.
///
/// `save(_:)` writes the file atomically and updates the cached `state` on success so observers re-render
/// without a separate reload step.
@MainActor
public protocol EnvFileRepository: Sendable {
    var state: LoadState<BrewEnvFile, any Error> { get }

    /// Cache-first by default. Refetches when forced, when the cache has been ``invalidate()``d, or
    /// when no value has loaded yet. Keeps any existing `.loaded` value on screen during the refetch.
    func load(forceRefresh: Bool) async

    func save(_ file: BrewEnvFile) async throws

    /// Marks the cached file as needing re-reading on the next `load()` call without disturbing the
    /// currently displayed value.
    func invalidate()
}
