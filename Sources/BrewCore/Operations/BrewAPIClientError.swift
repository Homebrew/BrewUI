//
//  BrewAPIClientError.swift
//  BrewCore
//

import Foundation

/// Failure surfaced by the Homebrew JSON API client. Lives in BrewCore so feature view models can map it
/// to user-facing copy without importing the networking layer (mirrors ``BrewCommandError``).
public enum BrewAPIClientError: Error, Equatable, Sendable {
    case invalidURL(path: String)
    case transport(underlying: String)
    case invalidResponse
    case httpStatus(code: Int, bodySnippet: String)
    case decoding(underlying: String)
}
