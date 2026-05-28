//
//  InstalledPackagesRepository.swift
//  BrewRepositories
//

import BrewCore
import Foundation

/// App-scoped source of truth for installed/outdated package state: the observable inventory plus the
/// synchronous status lookups and installed-id reads that surfaces render from. A single umbrella
/// abstraction so the environment can vend one repository all installed-aware features share.
@MainActor
public protocol InstalledPackagesRepository:
    InstalledInventoryObserving,
    InstalledPackageStatusReading,
    InstalledInventoryReading {}
