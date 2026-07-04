//
//  ConfigViewModel.swift
//  BrewFeatureConfig
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

@Observable
@MainActor
final class ConfigViewModel {
    @ObservationIgnored private let repository: any ConfigRepository

    init(repository: any ConfigRepository) {
        self.repository = repository
    }

    /// Mirrors the cached `brew config` snapshot owned by the repository — single source of truth across
    /// tab switches.
    var state: LoadState<BrewConfigSnapshot, any Error> {
        repository.state
    }

    /// Maps the repository state to a user-facing `LoadState` the view renders via `AsyncContentView`.
    /// Errors are converted to a message string so the standard error chrome needs no model knowledge.
    var pageState: LoadState<BrewConfigSnapshot, String> {
        switch state {
        case let .loaded(snapshot):
            .loaded(snapshot)
        case let .failed(error):
            .failed(userMessage(for: error))
        default:
            .loading
        }
    }

    /// Cache-first: subsequent appearances of the Configuration view hit the cached snapshot and don't
    /// trigger a re-fetch. The composition root (or scene-phase observer) calls `refresh()` to
    /// re-validate.
    func load() async {
        await repository.load(forceRefresh: false)
    }

    /// Forces a silent re-fetch. The repository keeps the existing `.loaded` value visible while the
    /// network work runs, so the view doesn't flash a loading state.
    func refresh() async {
        await repository.load(forceRefresh: true)
    }

    /// Maps any repository error to the user-facing copy shown in the AsyncContentView's error state.
    func userMessage(for error: any Error) -> String {
        if case let BrewCommandError.failed(_, stderr) = error {
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return String(
            localized: "Couldn't read the Homebrew configuration.",
            comment: "Configuration tab, generic load failure",
        )
    }
}
