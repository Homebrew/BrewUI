//
//  SelfUpdateDebugControl.swift
//  Brew
//

import Foundation
import Observation

#if DEBUG
    /// Switches for exercising the self-update UI, which a dev build never triggers on its own.
    @Observable
    @MainActor
    final class SelfUpdateDebugControl {
        var simulateUpdateAvailable = false

        /// Bumps the simulated version, for checking the banner reappears after "Later".
        var simulateNewerVersion = false

        var simulateUpdateHandoff = false

        var simulatedLatestVersion: String {
            simulateNewerVersion ? "100.0.0" : "99.0.0"
        }
    }
#endif
