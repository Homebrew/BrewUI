//
//  AIEngineProtocol.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import Foundation

/// Analyzes diagnostics and command output to generate explanations and safe fixes.
public protocol AIEngineProtocol: Sendable {
    func analyzeDoctorIssue(title: String, rawOutput: String) async -> AIAnalysisResult
    func analyzeCommandFailure(command: String, exitCode: Int, output: String) async -> AIAnalysisResult
    func semanticSearch(query: String, catalogue: [BrewPackage], limit: Int) async -> [AISemanticSearchResult]
    func assessUpgradeImpact(package: InstalledBrewPackage, targetVersion: String, dependents: [String]) async -> AIUpgradeImpact
    func generateBrewfileEnvironment(prompt: String) async -> AIBrewfileEnvironment
    func assessHousekeeping(installedPackages: [InstalledBrewPackage], leaves: [String]) async -> AIHousekeepingReport
    func suggestAlternatives(for package: BrewPackage) async -> [AIPackageAlternative]
    func recommendPackages(basedOn installedPackages: [InstalledBrewPackage]) async -> [AIPackageRecommendation]
    func comparePackages(packageA: BrewPackage, packageB: BrewPackage) async -> AIPackageComparison
}

/// Download state for a model.
public enum AIModelDownloadState: Sendable, Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case ready
}

/// Manages downloaded models, downloads, and active selection.
@MainActor
public protocol AIModelManaging: AnyObject, Sendable {
    var availableModels: [AIModelSpec] { get }
    var activeModelID: String? { get }
    var hardwareProfile: AISystemHardwareProfile { get }

    func downloadState(for model: AIModelSpec) -> AIModelDownloadState
    func setActiveModel(id: String?)
    func startDownload(for model: AIModelSpec) async
    func cancelDownload(for model: AIModelSpec)
    func deleteModel(for model: AIModelSpec)
}
