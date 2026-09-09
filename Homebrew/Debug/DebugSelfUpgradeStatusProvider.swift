//
//  DebugSelfUpgradeStatusProvider.swift
//  Brew
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

#if DEBUG
    /// Reading the control's flags in the getter routes SwiftUI observation through them.
    @Observable
    @MainActor
    final class DebugSelfUpgradeStatusProvider: SelfUpgradeStatusProviding {
        private let base: any SelfUpgradeStatusProviding
        private let control: SelfUpgradeDebugControl

        init(base: any SelfUpgradeStatusProviding, control: SelfUpgradeDebugControl) {
            self.base = base
            self.control = control
        }

        var selfUpgradeStatus: SelfUpgradeStatus {
            let real = base.selfUpgradeStatus
            guard control.simulateUpgradeAvailable else {
                return real
            }
            return SelfUpgradeStatus(
                runningVersion: real.runningVersion,
                latestVersion: SelfUpgradeDebugControl.simulatedLatestVersion,
                homepageURL: SelfUpgradeIdentity.homepageURL,
                isUpgradeAvailable: true,
            )
        }
    }
#endif
