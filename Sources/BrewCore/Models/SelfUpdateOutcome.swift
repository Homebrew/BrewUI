//
//  SelfUpdateOutcome.swift
//  BrewCore
//

import Foundation

/// How the last attempt ended, reported by the helper across the quit/relaunch boundary. A failure relaunches
/// looking exactly like an ordinary start, so it has to be recorded.
public enum SelfUpdateOutcome: String, Sendable, CaseIterable {
    case succeeded
    case failed
}
