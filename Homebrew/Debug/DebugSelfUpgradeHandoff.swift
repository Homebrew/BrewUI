//
//  DebugSelfUpgradeHandoff.swift
//  Brew
//

import BrewRepositoryInterfaces
import Foundation

#if DEBUG
    /// Refuses the upgrade the debug banner fabricates, delegating verbatim when the banner is the real one:
    /// the real handoff would upgrade whatever copy is installed in `/Applications`, a different bundle.
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
