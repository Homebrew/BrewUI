//
//  SelfUpgradeStubs.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation
import Observation

public struct StubRunningAppVersionReader: RunningAppVersionReading {
    public let runningVersion: String

    public init(runningVersion: String) {
        self.runningVersion = runningVersion
    }
}

@Observable
@MainActor
public final class StubSelfUpgradeStatusProvider: SelfUpgradeStatusProviding {
    public var selfUpgradeStatus: SelfUpgradeStatus

    public init(selfUpgradeStatus: SelfUpgradeStatus) {
        self.selfUpgradeStatus = selfUpgradeStatus
    }
}

@Observable
@MainActor
public final class RecordingSelfUpgradeHandoff: SelfUpgradeHandoff {
    public private(set) var performCount = 0
    private let error: (any Error)?

    public init(error: (any Error)? = nil) {
        self.error = error
    }

    public func performUpgrade() async throws {
        performCount += 1
        if let error {
            throw error
        }
    }
}

@Observable
@MainActor
public final class StubSelfUpgradePreferences: SelfUpgradePreferences {
    public var dismissedVersion: String?

    public init(dismissedVersion: String? = nil) {
        self.dismissedVersion = dismissedVersion
    }
}
