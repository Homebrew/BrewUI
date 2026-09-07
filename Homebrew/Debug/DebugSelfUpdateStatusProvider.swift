//
//  DebugSelfUpdateStatusProvider.swift
//  Brew
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

#if DEBUG
    /// Overrides detection when ``SelfUpdateDebugControl`` asks it to, delegating verbatim otherwise.
    /// Reading the control's flags in the getter routes SwiftUI observation through them.
    @Observable
    @MainActor
    final class DebugSelfUpdateStatusProvider: SelfUpdateStatusProviding {
        private let base: any SelfUpdateStatusProviding
        private let control: SelfUpdateDebugControl

        init(base: any SelfUpdateStatusProviding, control: SelfUpdateDebugControl) {
            self.base = base
            self.control = control
        }

        var selfUpdateStatus: SelfUpdateStatus {
            let real = base.selfUpdateStatus
            guard control.simulateUpdateAvailable else {
                return real
            }
            return SelfUpdateStatus(
                runningVersion: real.runningVersion,
                latestVersion: control.simulatedLatestVersion,
                homepageURL: SelfUpdateIdentity.homepageURL,
                isUpdateAvailable: true,
            )
        }
    }
#endif
