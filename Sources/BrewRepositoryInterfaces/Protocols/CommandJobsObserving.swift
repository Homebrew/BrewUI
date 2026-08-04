//
//  CommandJobsObserving.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation
import Observation

/// Observable cache of command-center operations, for surfaces that render the live console.
/// Refines `Observable` so SwiftUI tracks `jobs`/`orderedIDs` reads through the existential.
@MainActor
public protocol CommandJobsObserving: Observable, Sendable {
    var jobs: [CommandJobID: CommandJob] { get }
    var orderedIDs: [CommandJobID] { get }
    func remove(id: CommandJobID)
    func clearCompleted()
}
