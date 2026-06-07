//
//  ConfigRepository.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

/// One-shot read of `brew config` plus the effective `HOMEBREW_*` environment.
public protocol ConfigRepository: Sendable {
    func loadConfig() async throws -> BrewConfigSnapshot
}
