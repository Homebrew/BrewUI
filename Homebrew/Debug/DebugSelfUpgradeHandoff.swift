//
//  DebugSelfUpgradeHandoff.swift
//  Brew
//

import BrewRepositoryInterfaces
import Foundation

#if DEBUG
    /// Refuses the upgrade the debug banner offers, and delegates verbatim when the banner is the real one.
    ///
    /// The debug toggle fabricates an upgrade for a build that has none. Handing that to the real handoff
    /// would quit this build and run `brew upgrade --cask homebrew-app` against whatever copy of the app is
    /// installed in `/Applications` — a different bundle, upgraded behind the user's back.
    struct DebugSelfUpgradeHandoff: SelfUpgradeHandoff {
        let base: any SelfUpgradeHandoff
        /// A closure, not a value: the debug menu can flip the simulation on mid-session.
        let isSimulatingUpgrade: @MainActor () -> Bool

        func performUpgrade() async throws {
            guard isSimulatingUpgrade() else {
                try await base.performUpgrade()
                return
            }
            throw SimulatedSelfUpgrade()
        }
    }

    /// Surfaces on the banner itself, where ``SelfUpgradeCoordinator`` puts a handoff failure.
    private struct SimulatedSelfUpgrade: LocalizedError {
        var errorDescription: String? {
            "Debug build: the upgrade is simulated, so nothing was upgraded."
        }
    }
#endif
