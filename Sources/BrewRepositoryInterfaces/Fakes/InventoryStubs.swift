//
//  InventoryStubs.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

public struct EmptyInstalledDependentsRepository: InstalledDependentsRepository {
    public init() {}

    public func installedDependents(for _: InstalledBrewPackage.ID) async -> [InstalledBrewPackage] {
        []
    }
}

public struct EmptyInstalledInventoryReading: InstalledInventoryReading {
    public init() {}

    public func installedPackageIDs() async -> Set<InstalledBrewPackage.ID> {
        []
    }
}

public struct StubInstalledDependentsRepository: InstalledDependentsRepository {
    private let provider: @Sendable (InstalledBrewPackage.ID) -> [InstalledBrewPackage]

    public init(provider: @escaping @Sendable (InstalledBrewPackage.ID) -> [InstalledBrewPackage]) {
        self.provider = provider
    }

    public func installedDependents(for packageID: InstalledBrewPackage.ID) async -> [InstalledBrewPackage] {
        provider(packageID)
    }
}

public struct StubInstalledInventoryReading: InstalledInventoryReading {
    private let installedIDs: Set<InstalledBrewPackage.ID>

    public init(installedIDs: Set<InstalledBrewPackage.ID>) {
        self.installedIDs = installedIDs
    }

    public func installedPackageIDs() async -> Set<InstalledBrewPackage.ID> {
        installedIDs
    }
}
