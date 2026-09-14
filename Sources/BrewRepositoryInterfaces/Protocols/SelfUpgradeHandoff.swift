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

/// Recoverable failure at the handoff boundary; presentation copy is decided by the UI layer.
public enum SelfUpgradeHandoffError: Error, Sendable {
    case operationRunning
    case helperUnavailable
}
