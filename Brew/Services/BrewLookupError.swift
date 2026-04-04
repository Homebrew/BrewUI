//
//  BrewLookupError.swift
//  Brew
//

import Foundation

/// Could not locate a `brew` executable in supported locations.
enum BrewLookupError: Error, Equatable {
    case executableNotFound
}
