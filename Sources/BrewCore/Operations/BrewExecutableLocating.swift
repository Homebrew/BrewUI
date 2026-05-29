//
//  BrewExecutableLocating.swift
//  BrewCore
//

import Foundation

/// Resolves the `brew` executable — real implementation is `BrewExecutableLocator` in `BrewCLI`; tests may inject fakes (`CONVENTIONS.md` — Testing).
public protocol BrewExecutableLocating: Sendable {
    func findBrewExecutable() throws -> URL
}
