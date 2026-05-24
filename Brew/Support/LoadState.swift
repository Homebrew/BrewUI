//
//  LoadState.swift
//  Brew
//

import Foundation

/// Mutually-exclusive async load states for a single observable value (`CONVENTIONS.md` — Loadable UI state).
///
/// `failed` carries a user-facing message; the producer is responsible for keeping prior
/// `loaded` data on screen when a refresh fails and only transitioning to `failed` when
/// there is nothing to show.
enum LoadState<Value> {
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        guard case let .loaded(value) = self else {
            return nil
        }
        return value
    }
}

extension LoadState: Equatable where Value: Equatable {}
