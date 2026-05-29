//
//  InventoryStubs.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

struct EmptyInstalledDependentsRepository: InstalledDependentsRepository {
    init() {}

    func installedDependents(for _: InstalledBrewPackage.ID) async -> [InstalledBrewPackage] {
        []
    }
}

struct EmptyInstalledInventoryReading: InstalledInventoryReading {
    init() {}

    func installedPackageIDs() async -> Set<InstalledBrewPackage.ID> {
        []
    }
}

struct StubInstalledDependentsRepository: InstalledDependentsRepository {
    private let provider: @Sendable (InstalledBrewPackage.ID) -> [InstalledBrewPackage]

    init(provider: @escaping @Sendable (InstalledBrewPackage.ID) -> [InstalledBrewPackage]) {
        self.provider = provider
    }

    func installedDependents(for packageID: InstalledBrewPackage.ID) async -> [InstalledBrewPackage] {
        provider(packageID)
    }
}

struct StubInstalledInventoryReading: InstalledInventoryReading {
    private let installedIDs: Set<InstalledBrewPackage.ID>

    init(installedIDs: Set<InstalledBrewPackage.ID>) {
        self.installedIDs = installedIDs
    }

    func installedPackageIDs() async -> Set<InstalledBrewPackage.ID> {
        installedIDs
    }
}
