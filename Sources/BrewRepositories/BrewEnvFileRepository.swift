//
//  BrewEnvFileRepository.swift
//  BrewRepositories
//

import BrewCLI
import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation
import OSLog

private let envFileRepositoryLogger = Logger(
    subsystem: "Homebrew.BrewUI",
    category: "BrewEnvFileRepository",
)

/// Live `EnvFileRepository`: app-scoped `@Observable` that reads `brew.env` from the locator-resolved
/// path (missing file → empty file, not an error) and persists edits atomically. The cached `state`
/// stays visible across tab switches and silently revalidates on `forceRefresh: true`.
@Observable
@MainActor
public final class BrewEnvFileRepository: EnvFileRepository {
    /// Cached file content. Stays `.loaded` across silent revalidations.
    public private(set) var state: LoadState<BrewEnvFile, any Error> = .loading

    /// Freshness flag set by ``invalidate()``. When `true`, the next `load()` re-reads the file even
    /// though `state` is `.loaded`. Cleared on a successful read or a successful save.
    @ObservationIgnored private var isStale: Bool = false

    @ObservationIgnored private let locator: BrewEnvFileLocator

    public init(locator: BrewEnvFileLocator) {
        self.locator = locator
    }

    public static func live() -> BrewEnvFileRepository {
        BrewEnvFileRepository(locator: BrewEnvFileLocator())
    }

    public func load(forceRefresh: Bool) async {
        let needsFetch = forceRefresh || isStale || state.value == nil
        guard needsFetch else {
            return
        }
        let hadCached = state.value != nil
        if !hadCached {
            state = .loading
        }
        do {
            let file = try await Self.read(at: locator.locate())
            state = .loaded(file)
            isStale = false
        } catch is CancellationError {
            return
        } catch {
            if hadCached {
                envFileRepositoryLogger.error(
                    "brew.env revalidation failed: \(error.localizedDescription, privacy: .public)",
                )
            } else {
                state = .failed(error)
            }
        }
    }

    public func invalidate() {
        isStale = true
    }

    private static func read(at url: URL) async throws -> BrewEnvFile {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return BrewEnvFile()
        }
        let data = try Data(contentsOf: url)
        let source = String(bytes: data, encoding: .utf8) ?? ""
        return BrewEnvFileParser.parse(source)
    }
}
