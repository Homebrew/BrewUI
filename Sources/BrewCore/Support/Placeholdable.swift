//
//  Placeholdable.swift
//  BrewCore
//

import Foundation

/// A type that can supply a representative placeholder value for redacted loading states.
///
/// Conforming types return a `placeholder` populated with realistic stub data (non-empty name,
/// plausible version, etc.) so a `.redacted(reason: .placeholder)` rendering sizes the same as the
/// eventual content.
public protocol Placeholdable {
    static var placeholder: Self { get }
}
