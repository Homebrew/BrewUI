//
//  InstalledInventoryObserving.swift
//  Brew
//

import Foundation
import Observation

/// Observable installed-inventory state plus its load lifecycle, for surfaces that render the whole list.
/// Refines `Observable` so SwiftUI tracks ``state`` reads through the existential.
@MainActor
protocol InstalledInventoryObserving: Observable, Sendable {
    var state: LoadState<[InstalledBrewPackage], any Error> { get }
    func load(forceRefresh: Bool) async
}

extension InstalledInventoryObserving {
    func load() async {
        await load(forceRefresh: false)
    }
}
