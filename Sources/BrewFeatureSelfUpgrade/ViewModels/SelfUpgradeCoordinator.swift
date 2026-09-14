/*
 * [INPUT]: 依赖交接协议、状态提供者与语言快照
 * [OUTPUT]: 保存类型化交接失败并在展示时解析消息
 * [POS]: 自升级协调层；语言变化不重发交接或重置升级状态
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  SelfUpgradeCoordinator.swift
//  BrewFeatureSelfUpgrade
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

@Observable
@MainActor
public final class SelfUpgradeCoordinator {
    public enum Phase: Equatable, Sendable {
        case idle
        case handingOff
        case failed(Failure)
    }

    public enum Failure: Equatable, Sendable {
        case operationRunning
        case helperUnavailable
        case diagnostic(String)
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

    public func failureMessage(localization: AppLocalization = AppLocalization()) -> String? {
        guard case let .failed(failure) = phase else { return nil }
        switch failure {
        case .operationRunning:
            return localization.string("Wait for the running Homebrew command to finish, then upgrade the Homebrew app.")
        case .helperUnavailable:
            return localization.string("The upgrade helper is missing from this build of the Homebrew app.")
        case let .diagnostic(message):
            return message
        }
    }

    /// An outdated cask with no version string has nothing to key a stored dismissal to, so this one
    /// lasts the session instead.
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
            switch error {
            case SelfUpgradeHandoffError.operationRunning:
                phase = .failed(.operationRunning)
            case SelfUpgradeHandoffError.helperUnavailable:
                phase = .failed(.helperUnavailable)
            default:
                phase = .failed(.diagnostic(error.localizedDescription))
            }
        }
    }

    public func registerLaunchOutcome(_ outcome: SelfUpgradeOutcome?) {
        lastLaunchOutcome = outcome
    }

    public func acknowledgeUpgradeCompletion() {
        lastLaunchOutcome = nil
    }
}
