//
//  SelfUpgradeHandoff.swift
//  BrewRepositoryInterfaces
//

import Foundation

/// Performs the self-upgrade by handing off to a short-lived external helper, then quitting.
///
/// ``performUpgrade()`` does not return on success — the app is gone. A thrown error means the handoff could
/// not be started.
@MainActor
public protocol SelfUpgradeHandoff: Sendable {
    func performUpgrade() async throws
}
