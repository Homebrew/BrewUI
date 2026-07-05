//
//  UnimplementedRepositories.swift
//  BrewAppEnvironment
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation
import Observation

private nonisolated func unimplemented(_ function: StaticString = #function) -> Never {
    fatalError("\(function): unimplemented — inject a repository at the composition root.")
}

@Observable
@MainActor
final class UnimplementedInstalledPackagesRepository: InstalledPackagesRepository {
    var state: LoadState<[InstalledBrewPackage], any Error> {
        unimplemented()
    }

    func load(forceRefresh _: Bool) async {
        unimplemented()
    }

    func isInstalled(_: HomebrewPackageID) -> Bool {
        unimplemented()
    }

    func info(for _: HomebrewPackageID) -> InstalledBrewPackage? {
        unimplemented()
    }

    func installedPackageIDs() async -> Set<InstalledBrewPackage.ID> {
        unimplemented()
    }
}

struct UnimplementedDiscoverPackagesRepository: DiscoverPackagesRepository {
    func loadTopPackages(limit _: Int, window _: BrewAnalyticsWindow) async throws -> DiscoverTopPackagesSnapshot {
        unimplemented()
    }
}

struct UnimplementedCatalogueRepository: CatalogueRepository {
    func package(for _: HomebrewPackageID) async throws -> BrewPackage? {
        unimplemented()
    }

    func searchPackages(matching _: String, limit _: Int) async throws -> [BrewPackage] {
        unimplemented()
    }
}

struct UnimplementedDependentsRepository: InstalledDependentsRepository {
    func installedDependents(for _: InstalledBrewPackage.ID) async -> [InstalledBrewPackage] {
        unimplemented()
    }
}

@Observable
@MainActor
final class UnimplementedDoctorRepository: DoctorRepository {
    var state: LoadState<DoctorReport, any Error> {
        unimplemented()
    }

    var isRefreshing: Bool {
        unimplemented()
    }

    func load() async {
        unimplemented()
    }
}

@Observable
@MainActor
final class UnimplementedConfigRepository: ConfigRepository {
    var state: LoadState<BrewConfigSnapshot, any Error> {
        unimplemented()
    }

    func load(forceRefresh _: Bool) async {
        unimplemented()
    }

    func invalidate() {
        unimplemented()
    }
}

struct UnimplementedMutatingCommandFactory: BrewMutatingCommandFactory {
    func installCommand(kind _: HomebrewPackageKind, name _: String) -> any BrewMutatingCommand {
        unimplemented()
    }

    func upgradeCommand(kind _: HomebrewPackageKind, name _: String) -> any BrewMutatingCommand {
        unimplemented()
    }

    func uninstallCommand(kind _: HomebrewPackageKind, name _: String) -> any BrewMutatingCommand {
        unimplemented()
    }

    func bulkUpgradeCommand() -> any BrewMutatingCommand {
        unimplemented()
    }

    func doctorFixCommand(arguments _: [String]) -> any BrewMutatingCommand {
        unimplemented()
    }
}

@Observable
@MainActor
final class UnimplementedCommandJobsObserving: CommandJobsObserving {
    var jobs: [BrewOperationID: CommandJob] {
        unimplemented()
    }

    var orderedIDs: [BrewOperationID] {
        unimplemented()
    }

    func remove(id _: BrewOperationID) {
        unimplemented()
    }

    func clearCompleted() {
        unimplemented()
    }
}

actor UnimplementedBrewCommandCenter: BrewCommandCenter {
    func phase(for _: BrewOperationID) async -> BrewOperationPhase {
        unimplemented()
    }

    func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        unimplemented()
    }

    func isActive(id _: BrewOperationID) async -> Bool {
        unimplemented()
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        unimplemented()
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        unimplemented()
    }

    func outputChanges(for _: BrewOperationID) async -> AsyncStream<BrewCommandOutputLine> {
        unimplemented()
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        unimplemented()
    }

    func submit(id _: BrewOperationID, command _: any BrewMutatingCommand) async throws {
        unimplemented()
    }
}
