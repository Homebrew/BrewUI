//
//  SelfUpdateStatusProviding.swift
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
public protocol SelfUpdateStatusProviding: Observable, Sendable {
    var selfUpdateStatus: SelfUpdateStatus { get }
}
