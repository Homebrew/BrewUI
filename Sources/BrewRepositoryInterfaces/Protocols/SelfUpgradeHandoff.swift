//
//  SelfUpgradeHandoff.swift
//  BrewRepositoryInterfaces
//

import Foundation

/// Hands off to a short-lived external helper, then quits: ``performUpgrade()`` does not return on success.
/// A thrown error means the handoff never started.
@MainActor
public protocol SelfUpgradeHandoff: Sendable {
    func performUpgrade() async throws
}

/// 交接边界的可恢复失败；具体文案由展示层决定。
public enum SelfUpgradeHandoffError: Error, Sendable {
    case operationRunning
    case helperUnavailable
}
