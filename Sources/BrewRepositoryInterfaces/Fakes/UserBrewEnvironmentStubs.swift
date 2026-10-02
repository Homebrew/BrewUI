//
//  UserBrewEnvironmentStubs.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

/// In-memory ``UserBrewEnvironmentStoring`` for tests and previews. Optionally records saves.
/// Safe to mark Sendable without checking: the stub is only mutated from a single test actor and is
/// never shared across concurrent tasks in production wiring.
// swiftlint:disable:next unchecked_sendable
public final class StubUserBrewEnvironmentStore: UserBrewEnvironmentStoring, @unchecked Sendable {
    public private(set) var settings: BrewProxySettings
    public private(set) var savedSettings: [BrewProxySettings] = []
    public var error: (any Error)?

    public init(settings: BrewProxySettings = .empty, error: (any Error)? = nil) {
        self.settings = settings
        self.error = error
    }

    public func loadProxySettings() throws -> BrewProxySettings {
        if let error {
            throw error
        }
        return settings
    }

    public func saveProxySettings(_ settings: BrewProxySettings) throws {
        if let error {
            throw error
        }
        self.settings = settings
        savedSettings.append(settings)
    }
}
