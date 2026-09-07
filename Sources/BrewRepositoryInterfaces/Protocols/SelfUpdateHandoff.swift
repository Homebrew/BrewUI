//
//  SelfUpdateHandoff.swift
//  BrewRepositoryInterfaces
//

import Foundation

/// Performs the self-update by handing off to a short-lived external helper, then quitting.
///
/// ``performUpdate()`` does not return on success — the app is gone. A thrown error means the handoff could
/// not be started.
@MainActor
public protocol SelfUpdateHandoff: Sendable {
    func performUpdate() async throws
}
