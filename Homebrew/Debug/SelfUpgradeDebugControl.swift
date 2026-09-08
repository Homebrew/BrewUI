//
//  SelfUpgradeDebugControl.swift
//  Brew
//

import Foundation
import Observation

#if DEBUG
    /// Puts the self-upgrade banner on screen in a dev build, which is never the installed cask and so never
    /// has an upgrade of its own. Showing the banner is all it does: ``DebugSelfUpgradeHandoff`` refuses the
    /// upgrade the banner offers.
    @Observable
    @MainActor
    final class SelfUpgradeDebugControl {
        var simulateUpgradeAvailable = false

        /// A version no release will reach, so the banner reads as the debug one it is.
        static let simulatedLatestVersion = "99.0.0"
    }
#endif
