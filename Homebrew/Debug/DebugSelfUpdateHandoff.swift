//
//  DebugSelfUpdateHandoff.swift
//  Brew
//

import BrewRepositoryInterfaces
import Foundation

#if DEBUG
    /// Refuses the upgrade the debug banner offers, and delegates verbatim when the banner is the real one.
    ///
    /// The debug toggle fabricates an update for a build that has none. Handing that to the real handoff
    /// would quit this build and run `brew upgrade --cask homebrew-app` against whatever copy of the app is
    /// installed in `/Applications` — a different bundle, upgraded behind the user's back.
    struct DebugSelfUpdateHandoff: SelfUpdateHandoff {
        let base: any SelfUpdateHandoff
        /// A closure, not a value: the debug menu can flip the simulation on mid-session.
        let isSimulatingUpdate: @MainActor () -> Bool

        func performUpdate() async throws {
            guard isSimulatingUpdate() else {
                try await base.performUpdate()
                return
            }
            throw SimulatedSelfUpdate()
        }
    }

    /// Surfaces on the banner itself, where ``SelfUpdateCoordinator`` puts a handoff failure.
    private struct SimulatedSelfUpdate: LocalizedError {
        var errorDescription: String? {
            "Debug build: the update is simulated, so nothing was upgraded."
        }
    }
#endif
