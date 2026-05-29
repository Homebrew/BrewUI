//
//  BrewLookupError.swift
//  BrewCore
//

import Foundation

/// Could not locate a `brew` executable in supported locations.
public enum BrewLookupError: Error, Equatable, Sendable {
    case executableNotFound
}
