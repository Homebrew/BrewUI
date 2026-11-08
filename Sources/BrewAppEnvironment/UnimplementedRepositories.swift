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

    var refreshFailure: (any Error)? {
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

@Observable
@MainActor
final class UnimplementedDiscoverPackagesRepository: DiscoverPackagesRepository {
    var state: LoadState<[DiscoveryBrewPackage], any Error> {
        unimplemented()
    }

    func load(forceRefresh _: Bool) async {
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

    var reportedAt: Date? {
        unimplemented()
    }

    var isRefreshing: Bool {
        unimplemented()
    }

    func load(forceRefresh _: Bool) async {
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

@Observable
@MainActor
final class UnimplementedServicesRepository: ServicesRepository {
    var operation: BrewServiceOperation? {
        unimplemented()
    }

    var state: LoadState<[BrewService], any Error> {
        unimplemented()
    }

    var refreshFailure: (any Error)? {
        unimplemented()
    }

    var isRefreshing: Bool {
        unimplemented()
    }

    func load(forceRefresh _: Bool) async {
        unimplemented()
    }

    func perform(_: BrewServiceAction, serviceID _: String) async {
        unimplemented()
    }
}

struct UnimplementedMutatingCommandFactory: BrewMutatingCommandFactory {
    func installCommand(kind _: HomebrewPackageKind, name _: String) -> BrewCommand {
        unimplemented()
    }

    func upgradeCommand(kind _: HomebrewPackageKind, name _: String) -> BrewCommand {
        unimplemented()
    }

    func uninstallCommand(kind _: HomebrewPackageKind, name _: String) -> BrewCommand {
        unimplemented()
    }

    func bulkUpgradeCommand(selection _: BrewUpgradeSelection) -> BrewCommand {
        unimplemented()
    }

    func doctorFixCommand(arguments _: [String]) -> BrewCommand {
        unimplemented()
    }

    func bundleDumpCommand(fileURL _: URL) -> BrewCommand {
        unimplemented()
    }
}

@Observable
@MainActor
final class UnimplementedCommandJobsObserving: CommandJobsObserving {
    var jobs: [CommandJobID: CommandJob] {
        unimplemented()
    }

    var orderedIDs: [CommandJobID] {
        unimplemented()
    }

    func remove(id _: CommandJobID) {
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

    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] {
        unimplemented()
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        unimplemented()
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        unimplemented()
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        unimplemented()
    }

    func capture(_: BrewCommand, id _: BrewOperationID) async throws -> CommandOutput {
        unimplemented()
    }

    func perform(_: BrewCommand, id _: BrewOperationID) async throws {
        unimplemented()
    }
}

public struct UnimplementedAIEngine: AIEngineProtocol, Sendable {
    public init() {}
    public func analyzeDoctorIssue(title _: String, rawOutput _: String) async -> AIAnalysisResult {
        unimplemented()
    }

    public func analyzeCommandFailure(command _: String, exitCode _: Int, output _: String) async -> AIAnalysisResult {
        unimplemented()
    }

    public func semanticSearch(query _: String, catalogue _: [BrewPackage], limit _: Int) async -> [AISemanticSearchResult] {
        unimplemented()
    }

    public func assessUpgradeImpact(package _: InstalledBrewPackage, targetVersion _: String, dependents _: [String]) async -> AIUpgradeImpact {
        unimplemented()
    }

    public func generateBrewfileEnvironment(prompt _: String) async -> AIBrewfileEnvironment {
        unimplemented()
    }

    public func assessHousekeeping(installedPackages _: [InstalledBrewPackage], leaves _: [String]) async -> AIHousekeepingReport {
        unimplemented()
    }

    public func suggestAlternatives(for _: BrewPackage) async -> [AIPackageAlternative] {
        unimplemented()
    }

    public func recommendPackages(basedOn _: [InstalledBrewPackage]) async -> [AIPackageRecommendation] {
        unimplemented()
    }

    public func comparePackages(packageA _: BrewPackage, packageB _: BrewPackage) async -> AIPackageComparison {
        unimplemented()
    }
}

@Observable
@MainActor
public final class UnimplementedAIModelManager: AIModelManaging {
    public init() {}
    public var availableModels: [AIModelSpec] {
        unimplemented()
    }

    public var activeModelID: String? {
        unimplemented()
    }

    public var hardwareProfile: AISystemHardwareProfile {
        unimplemented()
    }

    public var lastErrorMessage: String? {
        unimplemented()
    }

    public func downloadState(for _: AIModelSpec) -> AIModelDownloadState {
        unimplemented()
    }

    public func setActiveModel(id _: String?) {
        unimplemented()
    }

    public func startDownload(for _: AIModelSpec) async {
        unimplemented()
    }

    public func cancelDownload(for _: AIModelSpec) {
        unimplemented()
    }

    public func deleteModel(for _: AIModelSpec) {
        unimplemented()
    }
}
