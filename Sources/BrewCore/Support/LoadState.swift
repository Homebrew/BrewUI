//
//  LoadState.swift
//  BrewCore
//

import Foundation

/// Mutually-exclusive async load states for a single observable value (`CONVENTIONS.md` — Loadable UI state).
///
/// `failed` carries a typed `Failure` (e.g. an `Error` surfaced by a repository); presentation layers
/// map it to user-facing copy. The producer keeps prior `loaded` data on screen when a refresh fails,
/// only transitioning to `failed` when there is nothing to show.
public enum LoadState<Value, Failure> {
    case loading
    case loaded(Value)
    case failed(Failure)

    public var value: Value? {
        guard case let .loaded(value) = self else {
            return nil
        }
        return value
    }
}

extension LoadState: Equatable where Value: Equatable, Failure: Equatable {}
