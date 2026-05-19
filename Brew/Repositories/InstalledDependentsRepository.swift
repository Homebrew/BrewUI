//
//  InstalledDependentsRepository.swift
//  Brew
//

import Foundation

/// Reverse dependency lookups over the installed inventory snapshot.
@MainActor
protocol InstalledDependentsRepository: Sendable {
    func installedDependents(for packageID: InstalledBrewPackage.ID) async -> [InstalledBrewPackage]
}
