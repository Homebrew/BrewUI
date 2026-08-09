//
//  BrewCommandExecutionContext+UITesting.swift
//  BrewCLI
//

import BrewCore
import Foundation

public extension BrewCommandExecutionContext {
    /// The real ``BrewCommandService`` pointed at a fake `brew`, so spawning, pipes and streaming stay
    /// under test. Deliberately *not* ``LoginShellBrewCommandRunner``: wrapping the fake in the
    /// developer's login shell would source their dotfiles and make runs machine-dependent.
    ///
    /// `nil` resolves nothing, which drives the brew-not-found surfaces and stops a launch that named
    /// no fake from falling through to a real Homebrew install.
    static func uiTesting(brewURL: URL?) -> BrewCommandExecutionContext {
        BrewCommandExecutionContext(
            commandRunner: BrewCommandService(),
            locator: brewURL.map { BrewExecutableLocator(overrideURL: $0) } ?? UnresolvableBrewExecutableLocator(),
        )
    }
}

/// Locator that never resolves, standing in for a machine with no Homebrew installed.
private struct UnresolvableBrewExecutableLocator: BrewExecutableLocating {
    func findBrewExecutable() throws -> URL {
        throw BrewLookupError.executableNotFound
    }
}
