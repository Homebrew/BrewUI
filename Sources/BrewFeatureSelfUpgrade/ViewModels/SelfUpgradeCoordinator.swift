//
//  SelfUpgradeCoordinator.swift
//  BrewFeatureSelfUpgrade
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

@Observable
@MainActor
public final class SelfUpgradeCoordinator {
    public enum Phase: Equatable, Sendable {
        case idle
        case handingOff
        case failed(String)
    }

    @ObservationIgnored private let statusProvider: any SelfUpgradeStatusProviding
    @ObservationIgnored private let preferences: any SelfUpgradePreferences
    @ObservationIgnored private let handoff: any SelfUpgradeHandoff

    public private(set) var phase: Phase = .idle

    /// `nil` on an ordinary launch.
    public private(set) var lastLaunchOutcome: SelfUpgradeOutcome?

    public var didJustCompleteUpgrade: Bool {
        lastLaunchOutcome == .succeeded
    }

    /// Distinct from ``didJustCompleteUpgrade`` because the app looks identical either way at launch.
    public var didJustFailUpgrade: Bool {
        lastLaunchOutcome == .failed
    }

    public init(
        statusProvider: any SelfUpgradeStatusProviding,
        preferences: any SelfUpgradePreferences,
        handoff: any SelfUpgradeHandoff,
    ) {
        self.statusProvider = statusProvider
        self.preferences = preferences
        self.handoff = handoff
    }

    public var status: SelfUpgradeStatus {
        statusProvider.selfUpgradeStatus
    }

    public var isUpgradeAvailable: Bool {
        status.isUpgradeAvailable
    }

    public var isUpgradeInProgress: Bool {
        phase == .handingOff
    }

    /// Governs both Upgrade and Later: "Later" defers an upgrade, so it means nothing once one is under way.
    public var isUpgradeActionEnabled: Bool {
        !isUpgradeInProgress && isUpgradeAvailable
    }

    public var failureMessage: String? {
        guard case let .failed(message) = phase else {
            return nil
        }
        return message
    }

    /// Set when "Later" is pressed on an upgrade brew reports as outdated without a version string. There
    /// is no version to key a stored dismissal to, so that one lasts the session rather than persisting.
    private var didDismissUnversionedUpgrade = false

    public var isBannerVisible: Bool {
        guard status.isUpgradeAvailable else {
            return false
        }
        guard let latestVersion = status.latestVersion else {
            return !didDismissUnversionedUpgrade
        }
        return preferences.dismissedVersion != latestVersion
    }

    public func dismiss() {
        guard let latestVersion = status.latestVersion else {
            didDismissUnversionedUpgrade = true
            return
        }
        preferences.dismissedVersion = latestVersion
    }

    /// Does not return in production — the app quits. A failure to *start* lands in ``phase``.
    public func beginUpgrade() async {
        guard phase != .handingOff, status.isUpgradeAvailable else {
            return
        }
        phase = .handingOff
        do {
            try await handoff.performUpgrade()
            // Reached only if the handoff returned without terminating (e.g. the stubbed helper).
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    public func registerLaunchOutcome(_ outcome: SelfUpgradeOutcome?) {
        lastLaunchOutcome = outcome
    }

    public func acknowledgeUpgradeCompletion() {
        lastLaunchOutcome = nil
    }
}
