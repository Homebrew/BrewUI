//
//  CleanupRoot.swift
//  BrewFeatureCleanup
//

import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import SwiftUI

/// Dependency-composition boundary for the Cleanup tab: reads app-level dependencies from the environment
/// and hands them to the content view, which owns the view model (`ARCHITECTURE.md` — root-view ownership).
public struct CleanupRoot: View {
    @Environment(\.cleanupRepository) private var cleanupRepository
    @Environment(\.brewCommandCenter) private var brewCommandCenter
    @Environment(\.mutatingCommandFactory) private var mutatingCommandFactory

    public init() {}

    public var body: some View {
        CleanupView(
            repository: cleanupRepository,
            commandCenter: brewCommandCenter,
            commandFactory: mutatingCommandFactory,
        )
    }
}
