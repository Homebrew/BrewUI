//
//  AIModels.swift
//  BrewCore
//

import Foundation

/// Specification for a downloadable local AI model.
public struct AIModelSpec: Identifiable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let parameterSize: String
    public let quantization: String
    public let downloadSizeMB: Int
    public let requiredMemoryGB: Double
    public let summary: String
    public let downloadURL: URL
    public let filename: String

    public init(
        id: String,
        name: String,
        parameterSize: String,
        quantization: String,
        downloadSizeMB: Int,
        requiredMemoryGB: Double,
        summary: String,
        downloadURL: URL,
        filename: String,
    ) {
        self.id = id
        self.name = name
        self.parameterSize = parameterSize
        self.quantization = quantization
        self.downloadSizeMB = downloadSizeMB
        self.requiredMemoryGB = requiredMemoryGB
        self.summary = summary
        self.downloadURL = downloadURL
        self.filename = filename
    }
}

/// How well a model fits the host Mac's unified memory.
public enum AISystemFit: String, Sendable, Equatable {
    case optimal
    case acceptable
    case heavy

    public var label: String {
        switch self {
        case .optimal: "Optimal Fit"
        case .acceptable: "Acceptable Fit"
        case .heavy: "Heavy Memory Usage"
        }
    }
}

/// Host hardware memory profile for model fit evaluation.
public struct AISystemHardwareProfile: Sendable, Equatable {
    public let totalMemoryBytes: UInt64
    public let totalMemoryGB: Double

    public init(totalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory) {
        self.totalMemoryBytes = totalMemoryBytes
        totalMemoryGB = Double(totalMemoryBytes) / 1_073_741_824.0
    }

    public func fit(for model: AIModelSpec) -> AISystemFit {
        guard totalMemoryGB > 0 else { return .heavy }
        let memoryRatio = model.requiredMemoryGB / totalMemoryGB
        if memoryRatio <= 0.25 {
            return .optimal
        } else if memoryRatio <= 0.50 {
            return .acceptable
        } else {
            return .heavy
        }
    }
}

/// Curated catalog of tested, high-efficiency local models for CLI and Homebrew diagnostics.
public enum AIModelCatalog: Sendable {
    public static let smolLM2 = AIModelSpec(
        id: "smollm2-1.7b",
        name: "SmolLM2 1.7B Instruct",
        parameterSize: "1.7B",
        quantization: "Q4_K_M",
        downloadSizeMB: 1050,
        requiredMemoryGB: 1.8,
        summary: "Ultra-fast, lightweight model ideal for quick diagnostic summaries and low-RAM systems.",
        downloadURL: URL(string: "https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf")!,
        filename: "smollm2-1.7b-instruct-q4_k_m.gguf",
    )

    public static let qwenCoder15B = AIModelSpec(
        id: "qwen2.5-coder-1.5b",
        name: "Qwen2.5-Coder 1.5B Instruct",
        parameterSize: "1.5B",
        quantization: "Q4_K_M",
        downloadSizeMB: 980,
        requiredMemoryGB: 1.9,
        summary: "Specialized for command-line syntax, compiler error resolution, and shell remediation.",
        downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf")!,
        filename: "qwen2.5-coder-1.5b-instruct-q4_k_m.gguf",
    )

    public static let llama323B = AIModelSpec(
        id: "llama-3.2-3b",
        name: "Llama 3.2 3B Instruct",
        parameterSize: "3B",
        quantization: "Q4_K_M",
        downloadSizeMB: 2020,
        requiredMemoryGB: 3.5,
        summary: "High reasoning capacity for complex doctor diagnostics and multi-dependency conflicts.",
        downloadURL: URL(string: "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf")!,
        filename: "llama-3.2-3b-instruct-q4_k_m.gguf",
    )

    public static let allModels: [AIModelSpec] = [
        qwenCoder15B,
        smolLM2,
        llama323B,
    ]
}

/// Structured outcome of an AI diagnostic analysis.
public struct AIAnalysisResult: Sendable, Equatable {
    public let summary: String
    public let rootCause: String
    public let suggestedCommands: [String]
    public let modelName: String

    public init(
        summary: String,
        rootCause: String,
        suggestedCommands: [String],
        modelName: String,
    ) {
        self.summary = summary
        self.rootCause = rootCause
        self.suggestedCommands = suggestedCommands
        self.modelName = modelName
    }
}

/// Result of an AI-powered semantic package search.
public struct AISemanticSearchResult: Identifiable, Sendable, Equatable {
    public var id: BrewPackage.ID {
        package.id
    }

    public let package: BrewPackage
    public let relevanceScore: Double
    public let matchReason: String

    public init(package: BrewPackage, relevanceScore: Double, matchReason: String) {
        self.package = package
        self.relevanceScore = relevanceScore
        self.matchReason = matchReason
    }
}

/// Risk level classification for package upgrades.
public enum AIRiskLevel: String, Sendable, Equatable {
    case low
    case medium
    case high

    public var title: String {
        switch self {
        case .low: "Low Risk"
        case .medium: "Medium Risk"
        case .high: "High Risk"
        }
    }
}

/// Evaluation of upgrade risks, major version changes, and downstream dependents.
public struct AIUpgradeImpact: Sendable, Equatable {
    public let packageName: String
    public let currentVersion: String
    public let targetVersion: String
    public let riskLevel: AIRiskLevel
    public let isMajorVersionBump: Bool
    public let affectedDependents: [String]
    public let summary: String
    public let breakingChangesWarning: String?
    public let serviceRestartNotice: String?
    public let recommendedVerificationCommands: [String]

    public init(
        packageName: String,
        currentVersion: String,
        targetVersion: String,
        riskLevel: AIRiskLevel,
        isMajorVersionBump: Bool,
        affectedDependents: [String],
        summary: String,
        breakingChangesWarning: String? = nil,
        serviceRestartNotice: String? = nil,
        recommendedVerificationCommands: [String] = [],
    ) {
        self.packageName = packageName
        self.currentVersion = currentVersion
        self.targetVersion = targetVersion
        self.riskLevel = riskLevel
        self.isMajorVersionBump = isMajorVersionBump
        self.affectedDependents = affectedDependents
        self.summary = summary
        self.breakingChangesWarning = breakingChangesWarning
        self.serviceRestartNotice = serviceRestartNotice
        self.recommendedVerificationCommands = recommendedVerificationCommands
    }
}

/// Conversational environment and Brewfile blueprint generated by AI.
public struct AIBrewfileEnvironment: Sendable, Equatable {
    public let title: String
    public let prompt: String
    public let taps: [String]
    public let formulae: [String]
    public let casks: [String]
    public let generatedBrewfileContent: String
    public let bundleCommand: String
    public let explanation: String

    public init(
        title: String,
        prompt: String,
        taps: [String],
        formulae: [String],
        casks: [String],
        generatedBrewfileContent: String,
        bundleCommand: String,
        explanation: String,
    ) {
        self.title = title
        self.prompt = prompt
        self.taps = taps
        self.formulae = formulae
        self.casks = casks
        self.generatedBrewfileContent = generatedBrewfileContent
        self.bundleCommand = bundleCommand
        self.explanation = explanation
    }
}

/// Safety assessment for pruning an orphan leaf package.
public enum AISafetyLevel: String, Sendable, Equatable {
    case safeToPrune
    case reviewRecommended

    public var title: String {
        switch self {
        case .safeToPrune: "Safe to Remove"
        case .reviewRecommended: "Review First"
        }
    }
}

/// Candidate orphan package identified during housekeeping analysis.
public struct AIOrphanCandidate: Identifiable, Sendable, Equatable {
    public var id: String {
        packageName
    }

    public let packageName: String
    public let installedVersion: String
    public let reason: String
    public let safetyLevel: AISafetyLevel

    public init(
        packageName: String,
        installedVersion: String,
        reason: String,
        safetyLevel: AISafetyLevel,
    ) {
        self.packageName = packageName
        self.installedVersion = installedVersion
        self.reason = reason
        self.safetyLevel = safetyLevel
    }
}

/// Storage reclamation and unused package report.
public struct AIHousekeepingReport: Sendable, Equatable {
    public let orphanCandidates: [AIOrphanCandidate]
    public let summary: String
    public let recommendedCommands: [String]
    public let reclaimableEstimate: String

    public init(
        orphanCandidates: [AIOrphanCandidate],
        summary: String,
        recommendedCommands: [String],
        reclaimableEstimate: String,
    ) {
        self.orphanCandidates = orphanCandidates
        self.summary = summary
        self.recommendedCommands = recommendedCommands
        self.reclaimableEstimate = reclaimableEstimate
    }
}

/// A modern alternative or complement to a given package.
public struct AIPackageAlternative: Identifiable, Sendable, Equatable {
    public var id: String {
        name
    }

    public let name: String
    public let relationship: String
    public let headline: String
    public let keyAdvantages: [String]
    public let installCommand: String
    public let isFormula: Bool

    public init(
        name: String,
        relationship: String,
        headline: String,
        keyAdvantages: [String],
        installCommand: String,
        isFormula: Bool = true,
    ) {
        self.name = name
        self.relationship = relationship
        self.headline = headline
        self.keyAdvantages = keyAdvantages
        self.installCommand = installCommand
        self.isFormula = isFormula
    }
}

/// Personalized package recommendation synthesized from installed machine environment.
public struct AIPackageRecommendation: Identifiable, Sendable, Equatable {
    public var id: String {
        packageName
    }

    public let packageName: String
    public let category: String
    public let reason: String
    public let confidenceScore: Double
    public let isCask: Bool

    public init(
        packageName: String,
        category: String,
        reason: String,
        confidenceScore: Double,
        isCask: Bool = false,
    ) {
        self.packageName = packageName
        self.category = category
        self.reason = reason
        self.confidenceScore = confidenceScore
        self.isCask = isCask
    }
}

/// Row comparing a single attribute between two packages.
public struct AIComparisonRow: Identifiable, Sendable, Equatable {
    public var id: String {
        feature
    }

    public let feature: String
    public let packageAValue: String
    public let packageBValue: String

    public init(
        feature: String,
        packageAValue: String,
        packageBValue: String,
    ) {
        self.feature = feature
        self.packageAValue = packageAValue
        self.packageBValue = packageBValue
    }
}

/// Side-by-side comparison report between two packages.
public struct AIPackageComparison: Sendable, Equatable {
    public let packageAName: String
    public let packageBName: String
    public let verdictSummary: String
    public let strengthsA: [String]
    public let strengthsB: [String]
    public let bestForA: String
    public let bestForB: String
    public let matrix: [AIComparisonRow]

    public init(
        packageAName: String,
        packageBName: String,
        verdictSummary: String,
        strengthsA: [String],
        strengthsB: [String],
        bestForA: String,
        bestForB: String,
        matrix: [AIComparisonRow],
    ) {
        self.packageAName = packageAName
        self.packageBName = packageBName
        self.verdictSummary = verdictSummary
        self.strengthsA = strengthsA
        self.strengthsB = strengthsB
        self.bestForA = bestForA
        self.bestForB = bestForB
        self.matrix = matrix
    }
}
