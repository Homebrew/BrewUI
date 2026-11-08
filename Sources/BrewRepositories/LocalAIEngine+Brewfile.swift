//
//  LocalAIEngine+Brewfile.swift
//  BrewRepositories
//
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation

extension LocalAIEngine {
    // MARK: - Brewfile & Environment Generator

    public func generateBrewfileEnvironment(prompt: String) async -> AIBrewfileEnvironment {
        let lower = prompt.lowercased()
        let words = Set(lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
        let hasAIOrML = words.contains("ai") || words.contains("ml")

        let config = resolveBrewfileConfig(lower: lower, words: words, hasAIOrML: hasAIOrML)
        let content = buildBrewfileContent(prompt: prompt, formulae: config.formulae, casks: config.casks, taps: config.taps)

        return AIBrewfileEnvironment(
            title: config.title,
            prompt: prompt,
            taps: config.taps,
            formulae: config.formulae,
            casks: config.casks,
            generatedBrewfileContent: content,
            bundleCommand: "brew bundle --file=Brewfile",
            explanation: config.explanation,
        )
    }

    private struct BrewfileStackConfig {
        let title: String
        let formulae: [String]
        let casks: [String]
        let taps: [String]
        let explanation: String
    }

    private func resolveBrewfileConfig(lower: String, words: Set<String>, hasAIOrML: Bool) -> BrewfileStackConfig {
        let isCloud = lower.contains("devops") || lower.contains("cloud") || lower.contains("docker")
            || lower.contains("k8s") || lower.contains("kubernetes") || lower.contains("terraform") || words.contains("aws")
        let isNode = lower.contains("node.js") || lower.contains("nodejs") || (words.contains("node") && !lower.contains("nodes") && !isCloud)
        let isWeb = lower.contains("web") || isNode || lower.contains("react") || lower.contains("typescript")

        if isCloud {
            return cloudStackConfig
        } else if isWeb {
            return webStackConfig
        } else if lower.contains("python") || lower.contains("data") || hasAIOrML {
            return pythonStackConfig
        } else if lower.contains("ios") || lower.contains("swift") || lower.contains("apple") || lower.contains("mobile") {
            return appleStackConfig
        } else if lower.contains("rust") || lower.contains("systems") || lower.contains("terminal") {
            return rustStackConfig
        } else {
            return customStackConfig
        }
    }

    private var cloudStackConfig: BrewfileStackConfig {
        BrewfileStackConfig(
            title: "DevOps, Cloud & Infrastructure Stack",
            formulae: ["git", "curl", "kubernetes-cli", "helm", "terraform", "awscli"],
            casks: ["docker"],
            taps: [],
            explanation: "Containerization, cluster management, and Infrastructure-as-Code utilities.",
        )
    }

    private var webStackConfig: BrewfileStackConfig {
        BrewfileStackConfig(
            title: "Modern Fullstack Web Stack",
            formulae: ["git", "curl", "node", "pnpm", "yarn", "gh"],
            casks: ["visual-studio-code", "google-chrome", "postman"],
            taps: [],
            explanation: "Node.js ecosystem toolchain with package managers, Git CLI, and development runtime.",
        )
    }

    private var pythonStackConfig: BrewfileStackConfig {
        BrewfileStackConfig(
            title: "Python Data & Machine Learning Stack",
            formulae: ["git", "curl", "python@3.12", "uv", "ffmpeg", "libomp"],
            casks: ["visual-studio-code", "jupyterlab"],
            taps: [],
            explanation: "High-performance Python 3.12 environment with uv package runner and C/OMP acceleration libraries.",
        )
    }

    private var appleStackConfig: BrewfileStackConfig {
        BrewfileStackConfig(
            title: "Apple Platform & Swift Engineering Stack",
            formulae: ["git", "curl", "swiftlint", "swiftformat", "xcbeautify", "cocoapods"],
            casks: ["sf-symbols"],
            taps: [],
            explanation: "Essential iOS/macOS developer toolchain for Swift linting, formatting, and Xcode build log beautification.",
        )
    }

    private var rustStackConfig: BrewfileStackConfig {
        BrewfileStackConfig(
            title: "Modern CLI & Rust Power Tools",
            formulae: ["git", "curl", "rustup-init", "ripgrep", "bat", "eza", "fd", "starship", "fzf"],
            casks: ["iterm2"],
            taps: [],
            explanation: "Blazing-fast modern command-line tools replacing legacy coreutils with Rust alternatives.",
        )
    }

    private var customStackConfig: BrewfileStackConfig {
        BrewfileStackConfig(
            title: "Custom Development Stack",
            formulae: ["git", "curl", "zsh-autosuggestions", "zsh-syntax-highlighting", "tree"],
            casks: ["visual-studio-code"],
            taps: [],
            explanation: "Tailored Brewfile configuration generated for your workflow.",
        )
    }

    private func buildBrewfileContent(prompt: String, formulae: [String], casks: [String], taps: [String]) -> String {
        var lines: [String] = []
        let promptLines = prompt.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if promptLines.isEmpty {
            lines.append("# AI-generated Brewfile")
        } else {
            lines.append("# AI-generated Brewfile for prompt:")
            for pLine in promptLines {
                lines.append("# \(pLine)")
            }
        }
        lines.append("# Run `brew bundle` to install this stack")
        lines.append("")

        for tap in taps {
            lines.append("tap \"\(tap)\"")
        }
        if !taps.isEmpty {
            lines.append("")
        }

        for formula in formulae {
            lines.append("brew \"\(formula)\"")
        }

        if !casks.isEmpty {
            lines.append("")
            for cask in casks {
                lines.append("cask \"\(cask)\"")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Smart Housekeeping & Orphan Detection

    public func assessHousekeeping(
        installedPackages: [InstalledBrewPackage],
        leaves: [String],
    ) async -> AIHousekeepingReport {
        var orphans: [AIOrphanCandidate] = []

        for leaf in leaves {
            if let pkg = installedPackages.first(where: { $0.name == leaf }) {
                let ver = pkg.installedVersions.first ?? "installed"
                let isOrphanDependency = !pkg.installedOnRequest

                orphans.append(
                    AIOrphanCandidate(
                        packageName: leaf,
                        installedVersion: ver,
                        reason: isOrphanDependency
                            ? "Installed as a dependency with no dependent packages; safe to prune."
                            : "Explicitly installed package with no dependents; safe to keep if you use it directly.",
                        safetyLevel: isOrphanDependency ? .safeToPrune : .reviewRecommended,
                    ),
                )
            }
        }

        let safeCount = orphans.count(where: { $0.safetyLevel == .safeToPrune })
        let estMB = safeCount * 85
        let reclaimable = estMB >= 1000 ? String(format: "%.1f GB", Double(estMB) / 1000.0) : "\(estMB) MB"

        return AIHousekeepingReport(
            orphanCandidates: orphans,
            summary: "Identified \(orphans.count) leaf package(s) on your system. \(safeCount) can be safely pruned to reclaim disk space.",
            recommendedCommands: ["brew autoremove --dry-run", "brew cleanup -s"],
            reclaimableEstimate: reclaimable,
        )
    }
}
