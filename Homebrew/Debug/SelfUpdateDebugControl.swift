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

        /// On by default: with it off, pressing Upgrade in a dev build runs a real
        /// `brew upgrade --cask homebrew-app` against whatever is installed in `/Applications`.
        var simulateUpdateHandoff = true

        var simulatedLatestVersion: String {
            simulateNewerVersion ? "100.0.0" : "99.0.0"
        }
    }
#endif
