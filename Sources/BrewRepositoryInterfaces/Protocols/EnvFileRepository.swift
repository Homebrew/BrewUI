//
//  EnvFileRepository.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

/// Read + atomic write of Homebrew's user-level `brew.env` — the single source of truth `brew` itself
/// sources on every invocation (`[[project-brewui-product-intent]]`).
public protocol EnvFileRepository: Sendable {
    func loadEnvFile() async throws -> BrewEnvFile
    func save(_ file: BrewEnvFile) async throws
}
