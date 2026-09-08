//
//  SelfUpgradeStatusProviding.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation
import Observation

/// A seam so detection can be tested without `Bundle.main`, which in a test process is the runner.
public protocol RunningAppVersionReading: Sendable {
    var runningVersion: String { get }
}

@MainActor
public protocol SelfUpgradeStatusProviding: Observable, Sendable {
    var selfUpgradeStatus: SelfUpgradeStatus { get }
}
