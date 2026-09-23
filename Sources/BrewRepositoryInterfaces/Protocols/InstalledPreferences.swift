//
//  InstalledPreferences.swift
//  BrewRepositoryInterfaces
//

import Foundation
import Observation

/// Installed-tab preferences that persist across launches.
@MainActor
public protocol InstalledPreferences: AnyObject, Observable, Sendable {
    /// Hides packages installed only as dependencies of something else.
    var hideDependencies: Bool { get set }
}
