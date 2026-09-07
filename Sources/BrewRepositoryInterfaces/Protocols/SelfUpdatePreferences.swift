//
//  SelfUpdatePreferences.swift
//  BrewRepositoryInterfaces
//

import Foundation
import Observation

@MainActor
public protocol SelfUpdatePreferences: AnyObject, Observable, Sendable {
    /// The version last dismissed with "Later". Per-version, so a newer release re-shows the banner.
    var dismissedVersion: String? { get set }
}
