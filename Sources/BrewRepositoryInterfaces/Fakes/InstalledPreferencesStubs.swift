//
//  InstalledPreferencesStubs.swift
//  BrewRepositoryInterfaces
//

import Foundation
import Observation

@Observable
@MainActor
public final class StubInstalledPreferences: InstalledPreferences {
    public var hideDependencies: Bool

    public init(hideDependencies: Bool = false) {
        self.hideDependencies = hideDependencies
    }
}
