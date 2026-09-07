//
//  SelfUpdateOutcome.swift
//  BrewCore
//

import Foundation

/// A failed attempt relaunches looking exactly like an ordinary start, so the outcome has to be recorded.
public enum SelfUpdateOutcome: String, Sendable, CaseIterable {
    case succeeded
    case failed
}
