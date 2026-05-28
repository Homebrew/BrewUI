//
//  BrewLookupError.swift
//  BrewCore
//

import Foundation

/// Could not locate a `brew` executable in supported locations.
public nonisolated enum BrewLookupError: Error, Equatable {
    case executableNotFound
}
