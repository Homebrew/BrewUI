//
//  BrewExecutableLocating.swift
//  Brew
//

import Foundation

/// Resolves the `brew` executable — real implementation is [`BrewExecutableLocator`](BrewExecutableLocator.swift); tests may inject fakes (`CONVENTIONS.md` — Testing).
protocol BrewExecutableLocating: Sendable {
    func findBrewExecutable() throws -> URL
}
