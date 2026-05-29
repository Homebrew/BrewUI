//
//  DoctorRepository.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

/// Read-only port for running `brew doctor` and returning a parsed ``DoctorReport``.
///
/// This is the diagnostics *read* path — it does not mutate Homebrew and does not go through the command
/// center. Running a suggested fix is a separate mutating operation submitted to ``BrewCommandCenter``.
public protocol DoctorRepository: Sendable {
    func runDiagnostics() async throws -> DoctorReport
}
