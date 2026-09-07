//
//  SelfUpdateCoordinator.swift
//  BrewFeatureSelfUpdate
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

@Observable
@MainActor
public final class SelfUpdateCoordinator {
    public enum Phase: Equatable, Sendable {
        case idle
        case handingOff
        case failed(String)
    }

    @ObservationIgnored private let statusProvider: any SelfUpdateStatusProviding
    @ObservationIgnored private let preferences: any SelfUpdatePreferences
    @ObservationIgnored private let handoff: any SelfUpdateHandoff

    public private(set) var phase: Phase = .idle

    /// `nil` on an ordinary launch.
    public private(set) var lastLaunchOutcome: SelfUpdateOutcome?

    public var didJustCompleteUpdate: Bool {
        lastLaunchOutcome == .succeeded
    }

    /// Distinct from ``didJustCompleteUpdate`` because the app looks identical either way at launch.
    public var didJustFailUpdate: Bool {
        lastLaunchOutcome == .failed
    }

    public init(
        statusProvider: any SelfUpdateStatusProviding,
        preferences: any SelfUpdatePreferences,
        handoff: any SelfUpdateHandoff,
    ) {
        self.statusProvider = statusProvider
        self.preferences = preferences
        self.handoff = handoff
    }

    public var status: SelfUpdateStatus {
        statusProvider.selfUpdateStatus
    }

    public var isUpdateAvailable: Bool {
        status.isUpdateAvailable
    }

    public var isUpgradeInProgress: Bool {
        phase == .handingOff
    }

    /// Governs both Upgrade and Later: "Later" defers an upgrade, so it means nothing once one is under way.
    public var isUpgradeActionEnabled: Bool {
        !isUpgradeInProgress && isUpdateAvailable
    }

    public var failureMessage: String? {
        guard case let .failed(message) = phase else {
            return nil
        }
        return message
    }

    public var isBannerVisible: Bool {
        status.isUpdateAvailable && preferences.dismissedVersion != status.latestVersion
    }

    public func dismiss() {
        preferences.dismissedVersion = status.latestVersion
    }

    /// Does not return in production — the app quits. A failure to *start* lands in ``phase``.
    public func beginUpdate() async {
        guard phase != .handingOff, status.isUpdateAvailable else {
            return
        }
        phase = .handingOff
        do {
            try await handoff.performUpdate()
            // Reached only if the handoff returned without terminating (e.g. the stubbed helper).
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    public func registerLaunchOutcome(_ outcome: SelfUpdateOutcome?) {
        lastLaunchOutcome = outcome
    }

    public func acknowledgeUpdateCompletion() {
        lastLaunchOutcome = nil
    }
}
