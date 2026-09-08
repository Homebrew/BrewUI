//
//  SelfUpgradePreferences.swift
//  BrewRepositoryInterfaces
//

import Foundation
import Observation

@MainActor
public protocol SelfUpgradePreferences: AnyObject, Observable, Sendable {
    /// Per-version, so a newer release re-shows the banner.
    var dismissedVersion: String? { get set }
}
