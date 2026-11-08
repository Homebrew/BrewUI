//
//  LocalAIEngine+Discovery.swift
//  BrewRepositories
//
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation

extension LocalAIEngine {
    // MARK: - Semantic Natural Language Discovery

    private struct SemanticCandidate {
        let package: BrewPackage
        let rawScore: Double
        let reason: String
    }

    public func semanticSearch(query: String, catalogue: [BrewPackage], limit: Int) async -> [AISemanticSearchResult] {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        let queryTokens = normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }

        var intermediateResults: [SemanticCandidate] = []

        for package in catalogue {
            if let candidate = scorePackage(package, normalized: normalized, queryTokens: queryTokens, query: query) {
                intermediateResults.append(candidate)
            }
        }

        intermediateResults.sort { lhs, rhs in
            let lhsExact = lhs.package.name.lowercased() == normalized
            let rhsExact = rhs.package.name.lowercased() == normalized
            if lhsExact != rhsExact {
                return lhsExact
            }
            return lhs.rawScore > rhs.rawScore
        }

        let results = intermediateResults.prefix(limit).map { item in
            AISemanticSearchResult(
                package: item.package,
                relevanceScore: min(item.rawScore, 1.0),
                matchReason: item.reason,
            )
        }
        return Array(results)
    }

    private func scorePackage(
        _ package: BrewPackage,
        normalized: String,
        queryTokens: [String],
        query: String,
    ) -> SemanticCandidate? {
        let name = package.name.lowercased()
        let desc = package.description.lowercased()
        var score = 0.0
        var matchedKeywords: [String] = []

        if name == normalized {
            score += 1.0
            matchedKeywords.append("exact name")
        } else if name.contains(normalized) {
            score += 0.8
            matchedKeywords.append("name match")
        }

        if desc.contains(normalized) {
            score += 0.7
            matchedKeywords.append("description phrase")
        }

        for token in queryTokens {
            if name.contains(token) {
                score += 0.4
                matchedKeywords.append(token)
            }
            if desc.contains(token) {
                score += 0.3
                matchedKeywords.append(token)
            }
        }

        applyIntentHeuristics(name: name, desc: desc, normalized: normalized, score: &score, matchedKeywords: &matchedKeywords)

        guard score > 0.3 else { return nil }

        let reason = matchedKeywords.isEmpty
            ? "Relevant match for “\(query)”"
            : "Matched via \(matchedKeywords.prefix(3).joined(separator: ", "))"

        return SemanticCandidate(package: package, rawScore: score, reason: reason)
    }

    private func applyIntentHeuristics(
        name: String,
        desc: String,
        normalized: String,
        score: inout Double,
        matchedKeywords: inout [String],
    ) {
        if normalized.contains("image"),
           name.contains("image") || desc.contains("image") || desc.contains("graphics") || name.contains("vips") || name.contains("magick")
        {
            score += 0.5
            matchedKeywords.append("image capability")
        }
        if normalized.contains("json") || normalized.contains("yaml"),
           desc.contains("json") || desc.contains("yaml") || desc.contains("parse") || desc.contains("processor")
        {
            score += 0.5
            matchedKeywords.append("data formatting capability")
        }
        if normalized.contains("monitor"), desc.contains("monitor") || desc.contains("process viewer") || desc.contains("system") {
            score += 0.5
            matchedKeywords.append("system monitoring")
        }
        if normalized.contains("fast") || normalized.contains("rust"),
           desc.contains("rust") || desc.contains("blazing fast") || desc.contains("replacement")
        {
            score += 0.4
            matchedKeywords.append("modern tool replacement")
        }
        if normalized.contains("git") || normalized.contains("vcs"), desc.contains("git") || desc.contains("version control") {
            score += 0.5
            matchedKeywords.append("version control")
        }
    }

    // MARK: - Personalized Machine Recommendations

    public func recommendPackages(
        basedOn installedPackages: [InstalledBrewPackage],
    ) async -> [AIPackageRecommendation] {
        let installedNames = Set(installedPackages.map { $0.name.lowercased() })
        var recommendations: [AIPackageRecommendation] = []

        appendGitRecommendations(to: &recommendations, installedNames: installedNames)
        appendPythonRecommendations(to: &recommendations, installedNames: installedNames)
        appendCliToolRecommendations(to: &recommendations, installedNames: installedNames)
        appendShellRecommendations(to: &recommendations, installedNames: installedNames)
        appendContainerRecommendations(to: &recommendations, installedNames: installedNames)
        appendProductivityRecommendations(to: &recommendations, installedNames: installedNames)

        return recommendations
    }

    private func appendPythonRecommendations(to recommendations: inout [AIPackageRecommendation], installedNames: Set<String>) {
        let hasPython = installedNames.contains(where: { $0.contains("python") })
        guard hasPython else { return }

        if !installedNames.contains("uv") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "uv",
                    category: "Python Development",
                    reason: "Extremely fast Python package and environment manager written in Rust. Replaces pip, pipx, and virtualenv.",
                    confidenceScore: 0.95,
                ),
            )
        }
    }

    private func appendGitRecommendations(to recommendations: inout [AIPackageRecommendation], installedNames: Set<String>) {
        let hasGit = installedNames.contains("git") || installedNames.contains(where: { $0.contains("git") })
        guard hasGit else { return }

        if !installedNames.contains("lazygit") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "lazygit",
                    category: "Git & Source Control",
                    reason: "You use Git. Lazygit provides an interactive terminal UI for rapid staging, rebasing, and branch navigation.",
                    confidenceScore: 0.96,
                ),
            )
        }
        if !installedNames.contains("gh") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "gh",
                    category: "Git & Source Control",
                    reason: "Official GitHub CLI tool to review pull requests, create releases, and manage issues directly from your terminal.",
                    confidenceScore: 0.94,
                ),
            )
        }
        if !installedNames.contains("git-delta"), !installedNames.contains("delta") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "git-delta",
                    category: "Git & Source Control",
                    reason: "Syntax-highlighting pager for git diffs with side-by-side view and word-level diffing.",
                    confidenceScore: 0.88,
                ),
            )
        }
    }

    private func appendCliToolRecommendations(to recommendations: inout [AIPackageRecommendation], installedNames: Set<String>) {
        if !installedNames.contains("ripgrep") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "ripgrep",
                    category: "CLI Power Tools",
                    reason: "Top-tier search utility that searches codebases up to 10x faster than standard grep.",
                    confidenceScore: 0.98,
                ),
            )
        }
        if !installedNames.contains("bat") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "bat",
                    category: "CLI Power Tools",
                    reason: "Cat clone with syntax highlighting and git integration for reading code in terminal.",
                    confidenceScore: 0.95,
                ),
            )
        }
        if !installedNames.contains("eza") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "eza",
                    category: "CLI Power Tools",
                    reason: "Modern replacement for ls with colourised metadata, Git status indicators, and tree support.",
                    confidenceScore: 0.93,
                ),
            )
        }
        if !installedNames.contains("fd") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "fd",
                    category: "CLI Power Tools",
                    reason: "Intuitive, ultra-fast alternative to find that ignores hidden and ignored files by default.",
                    confidenceScore: 0.91,
                ),
            )
        }
    }

    private func appendShellRecommendations(to recommendations: inout [AIPackageRecommendation], installedNames: Set<String>) {
        if !installedNames.contains("fzf") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "fzf",
                    category: "Shell Productivity",
                    reason: "Fuzzy finder for interactive command-line searches across history, files, and Git commits.",
                    confidenceScore: 0.97,
                ),
            )
        }
        if !installedNames.contains("starship") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "starship",
                    category: "Shell Productivity",
                    reason: "Fast, highly-customisable cross-shell prompt that shows git status, runtime versions, and package details.",
                    confidenceScore: 0.89,
                ),
            )
        }
        if !installedNames.contains("zoxide") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "zoxide",
                    category: "Shell Productivity",
                    reason: "Smarter cd command that remembers your most frequent directories for instant jumping.",
                    confidenceScore: 0.90,
                ),
            )
        }
    }

    private func appendContainerRecommendations(to recommendations: inout [AIPackageRecommendation], installedNames: Set<String>) {
        let hasContainers = installedNames.contains("docker") || installedNames.contains("colima") || installedNames.contains("podman")
        if hasContainers, !installedNames.contains("lazydocker") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "lazydocker",
                    category: "DevOps & Containers",
                    reason: "Simple terminal UI for managing Docker containers, images, and volumes without memorising flags.",
                    confidenceScore: 0.94,
                ),
            )
        }
        if !installedNames.contains("k9s"), installedNames.contains("kubernetes-cli") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "k9s",
                    category: "DevOps & Containers",
                    reason: "Terminal-based dashboard to navigate, observe, and manage Kubernetes clusters.",
                    confidenceScore: 0.92,
                ),
            )
        }
    }

    private func appendProductivityRecommendations(to recommendations: inout [AIPackageRecommendation], installedNames: Set<String>) {
        if !installedNames.contains("raycast") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "raycast",
                    category: "macOS Productivity",
                    reason: "Fast, extensible launcher for macOS with clipboard history, window management, and developer extensions.",
                    confidenceScore: 0.87,
                    isCask: true,
                ),
            )
        }
    }
}
