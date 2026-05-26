//
//  BrewLookupError.swift
//  Brew
//

import Foundation

/// Could not locate a `brew` executable in supported locations.
nonisolated enum BrewLookupError: Error, Equatable {
    case executableNotFound
}
