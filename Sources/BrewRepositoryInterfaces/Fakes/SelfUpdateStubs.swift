//
//  SelfUpdateStubs.swift
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
public final class StubSelfUpdateStatusProvider: SelfUpdateStatusProviding {
    public var selfUpdateStatus: SelfUpdateStatus

    public init(selfUpdateStatus: SelfUpdateStatus) {
        self.selfUpdateStatus = selfUpdateStatus
    }
}

@Observable
@MainActor
public final class RecordingSelfUpdateHandoff: SelfUpdateHandoff {
    public private(set) var performCount = 0
    private let error: (any Error)?

    public init(error: (any Error)? = nil) {
        self.error = error
    }

    public func performUpdate() async throws {
        performCount += 1
        if let error {
            throw error
        }
    }
}

@Observable
@MainActor
public final class StubSelfUpdatePreferences: SelfUpdatePreferences {
    public var dismissedVersion: String?

    public init(dismissedVersion: String? = nil) {
        self.dismissedVersion = dismissedVersion
    }
}
