//
//  InstalledDependentsRepository.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

/// Reverse dependency lookups over the installed inventory snapshot.
public protocol InstalledDependentsRepository: Sendable {
    func installedDependents(for packageID: InstalledBrewPackage.ID) async -> [InstalledBrewPackage]
}
