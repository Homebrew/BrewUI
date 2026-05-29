//
//  Stubs.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation
import Observation

/// Loaded-state installed inventory backed by an in-memory package list.
@Observable
@MainActor
public final class StubInstalledPackagesRepository: InstalledPackagesRepository {
    public private(set) var state: LoadState<[InstalledBrewPackage], any Error>
    private var lookup: [HomebrewPackageID: InstalledBrewPackage]

    public init(packages: [InstalledBrewPackage]) {
        state = .loaded(packages)
        lookup = Dictionary(packages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public init(state: LoadState<[InstalledBrewPackage], any Error>) {
        self.state = state
        let packages = state.value ?? []
        lookup = Dictionary(packages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func load(forceRefresh _: Bool) async {}
    public func isInstalled(_ id: HomebrewPackageID) -> Bool {
        lookup[id] != nil
    }

    public func info(for id: HomebrewPackageID) -> InstalledBrewPackage? {
        lookup[id]
    }

    public func installedPackageIDs() async -> Set<InstalledBrewPackage.ID> {
        Set(lookup.keys)
    }
}

public struct StubDiscoverPackagesRepository: DiscoverPackagesRepository {
    private let snapshot: DiscoverTopPackagesSnapshot

    public init(snapshot: DiscoverTopPackagesSnapshot) {
        self.snapshot = snapshot
    }

    public func loadTopPackages(
        limit _: Int,
        window _: BrewAnalyticsWindow,
    ) async throws -> DiscoverTopPackagesSnapshot {
        snapshot
    }
}

public struct StubCatalogueRepository: CatalogueRepository {
    private let formulaCatalogue: [BrewPackage]
    private let caskCatalogue: [BrewPackage]

    public init(formulaCatalogue: [BrewPackage], caskCatalogue: [BrewPackage]) {
        self.formulaCatalogue = formulaCatalogue
        self.caskCatalogue = caskCatalogue
    }

    public func package(for reference: HomebrewPackageID) async throws -> BrewPackage? {
        let packages = reference.kind == .formula ? formulaCatalogue : caskCatalogue
        return packages.first { $0.id == reference }
    }

    public func searchPackages(matching query: String, limit: Int) async throws -> [BrewPackage] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, limit > 0 else {
            return []
        }
        let matches = (formulaCatalogue + caskCatalogue).filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.displayName.localizedCaseInsensitiveContains(trimmedQuery)
        }
        return Array(matches.prefix(limit))
    }
}

struct StubDependentsRepository: InstalledDependentsRepository {
    private let dependentsByPackageID: [InstalledBrewPackage.ID: [InstalledBrewPackage]]

    init(dependentsByPackageID: [InstalledBrewPackage.ID: [InstalledBrewPackage]]) {
        self.dependentsByPackageID = dependentsByPackageID
    }

    func installedDependents(for packageID: InstalledBrewPackage.ID) async -> [InstalledBrewPackage] {
        dependentsByPackageID[packageID] ?? []
    }
}

/// Returns a fixed ``DoctorReport`` (or throws a fixed error) without running `brew` — for previews/tests.
public struct StubDoctorRepository: DoctorRepository {
    private let result: Result<DoctorReport, any Error & Sendable>

    public init(report: DoctorReport) {
        result = .success(report)
    }

    public init(error: any Error & Sendable) {
        result = .failure(error)
    }

    public func runDiagnostics() async throws -> DoctorReport {
        try result.get()
    }
}

/// No-op command center for previews/tests: immediate, with no phase bookkeeping. Uses only BrewCore.
public actor StubBrewCommandCenter: BrewCommandCenter {
    public init() {}

    public func phase(for _: BrewOperationID) async -> BrewOperationPhase {
        .idle
    }

    public func phaseByID() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    public func isActive(id _: BrewOperationID) async -> Bool {
        false
    }

    public func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        AsyncStream<BrewOperationPhase>(bufferingPolicy: .unbounded) { continuation in
            continuation.yield(.idle)
            continuation.finish()
        }
    }

    public func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream<(BrewOperationID, BrewOperationPhase)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    public func outputChanges(for _: BrewOperationID) async -> AsyncStream<BrewCommandOutputLine> {
        AsyncStream<BrewCommandOutputLine>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    public func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream<(BrewOperationID, BrewCommandOutputLine)>(bufferingPolicy: .unbounded) { continuation in
            continuation.finish()
        }
    }

    public func submit(id _: BrewOperationID, command _: any BrewMutatingCommand) async throws {}
}

/// Command that does nothing when run — for previews/tests that submit without touching `brew`.
struct NoopMutatingCommand: BrewMutatingCommand {
    let operationKind: BrewOperationKind

    func run(in _: BrewCommandExecutionContext) async throws {}
}

/// Factory vending no-op commands, so view models can be exercised without `brew`.
public struct StubMutatingCommandFactory: BrewMutatingCommandFactory {
    public init() {}

    public func installCommand(kind: HomebrewPackageKind, name _: String) -> any BrewMutatingCommand {
        NoopMutatingCommand(operationKind: kind == .formula ? .installFormula : .installCask)
    }

    public func upgradeCommand(kind: HomebrewPackageKind, name _: String) -> any BrewMutatingCommand {
        NoopMutatingCommand(operationKind: kind == .formula ? .upgradeFormula : .upgradeCask)
    }

    public func uninstallCommand(kind: HomebrewPackageKind, name _: String) -> any BrewMutatingCommand {
        NoopMutatingCommand(operationKind: kind == .formula ? .uninstallFormula : .uninstallCask)
    }

    public func doctorFixCommand(arguments _: [String]) -> any BrewMutatingCommand {
        NoopMutatingCommand(operationKind: .doctorFix)
    }
}
