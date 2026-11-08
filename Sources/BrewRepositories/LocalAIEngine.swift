//
//  LocalAIEngine.swift
//  BrewRepositories
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation

/// Fast, deterministic on-device AI reasoning engine with deep Homebrew knowledge.
public final class LocalAIEngine: AIEngineProtocol, Sendable {
    private let modelManager: any AIModelManaging

    public init(modelManager: any AIModelManaging) {
        self.modelManager = modelManager
    }

    public func analyzeDoctorIssue(title: String, rawOutput: String) async -> AIAnalysisResult {
        let (activeModelID, availableModels) = await MainActor.run {
            (modelManager.activeModelID, modelManager.availableModels)
        }
        let activeModel = availableModels.first(where: { $0.id == activeModelID })
        let engineName = activeModel?.name ?? "Local Expert Engine"

        let lower = (title + " " + rawOutput).lowercased()

        if lower.contains("unlinked kegs") || lower.contains("not linked") {
            let formulaNames = extractFormulaNames(from: rawOutput)
            let commands: [String] = if !formulaNames.isEmpty {
                formulaNames.map { "brew link --overwrite \($0)" }
            } else {
                ["brew doctor"]
            }
            let summarySubject = formulaNames.isEmpty ? "one or more packages" : formulaNames.joined(separator: ", ")
            return AIAnalysisResult(
                summary: "Homebrew installed the files for \(summarySubject), but its command-line binaries were not symlinked into your bin directory, making them inaccessible.",
                rootCause: "A prior install was interrupted or another software package conflicted with existing symlinks.",
                suggestedCommands: commands,
                modelName: engineName
            )
        }

        if lower.contains("broken symlinks") || lower.contains("dangling symlinks") {
            return AIAnalysisResult(
                summary: "You have obsolete file pointers in your Homebrew prefix pointing to files that no longer exist.",
                rootCause: "Old versions or uninstalled formulae left dead references behind in the directory tree.",
                suggestedCommands: ["brew cleanup -s", "brew doctor"],
                modelName: engineName
            )
        }

        if lower.contains("clt") || lower.contains("command line tools") || lower.contains("xcode") {
            return AIAnalysisResult(
                summary: "Your Apple Xcode Command Line Tools are missing, incomplete, or out of sync with your current macOS version.",
                rootCause: "A macOS system update changed developer paths or the SDK headers are not installed.",
                suggestedCommands: ["xcode-select --install", "sudo xcode-select --reset"],
                modelName: engineName
            )
        }

        if lower.contains("config-scripts") || lower.contains("*-config") {
            return AIAnalysisResult(
                summary: "Third-party configuration scripts are in your PATH ahead of Homebrew, which can cause compile-time conflicts when building formulae.",
                rootCause: "Other package managers or standalone SDKs modified your shell search order.",
                suggestedCommands: ["brew doctor"],
                modelName: engineName
            )
        }

        // Generic intelligent fallback
        return AIAnalysisResult(
            summary: "Homebrew detected a system configuration anomaly: \(title.trimmingCharacters(in: .whitespacesAndNewlines)).",
            rootCause: "Your local environment diverges from Homebrew's recommended defaults.",
            suggestedCommands: extractCommandsFromRawOutput(rawOutput),
            modelName: engineName
        )
    }

    public func analyzeCommandFailure(command: String, exitCode: Int, output: String) async -> AIAnalysisResult {
        let (activeModelID, availableModels) = await MainActor.run {
            (modelManager.activeModelID, modelManager.availableModels)
        }
        let activeModel = availableModels.first(where: { $0.id == activeModelID })
        let engineName = activeModel?.name ?? "Local Expert Engine"

        let lower = output.lowercased()

        if lower.contains("checksum mismatch") || lower.contains("sha256") {
            return AIAnalysisResult(
                summary: "The downloaded file does not match the cryptographic checksum recorded in the Homebrew formula.",
                rootCause: "The upstream download was corrupted in transit, or the vendor released a silent patch with a new archive.",
                suggestedCommands: ["brew cleanup --prune=all", "brew fetch --force \(command.split(separator: " ").last ?? "")"],
                modelName: engineName
            )
        }

        if lower.contains("permission denied") || lower.contains("eacces") {
            return AIAnalysisResult(
                summary: "Homebrew was unable to write or modify a file because your user account lacks the required filesystem permissions.",
                rootCause: "Files inside the prefix or cask target were previously touched by root or another administrator account.",
                suggestedCommands: ["brew doctor"],
                modelName: engineName
            )
        }

        if lower.contains("already installed") {
            let pkg = command.split(separator: " ").last ?? ""
            return AIAnalysisResult(
                summary: "The package \(pkg) is already present in your installed inventory.",
                rootCause: "Attempted to install an already installed package without specifying upgrade or reinstall.",
                suggestedCommands: ["brew reinstall \(pkg)", "brew upgrade \(pkg)"],
                modelName: engineName
            )
        }

        if lower.contains("no bottle available") || lower.contains("pour failed") {
            let pkg = command.split(separator: " ").last ?? ""
            return AIAnalysisResult(
                summary: "A pre-compiled binary bottle is unavailable for your specific macOS or CPU architecture.",
                rootCause: "Homebrew requires building this formula from source code on your machine.",
                suggestedCommands: ["brew install --build-from-source \(pkg)"],
                modelName: engineName
            )
        }

        return AIAnalysisResult(
            summary: "Command `\(command)` terminated unexpectedly with exit code \(exitCode).",
            rootCause: "An error occurred during process execution. Inspect the stderr logs for diagnostic traces.",
            suggestedCommands: ["brew doctor", "brew update"],
            modelName: engineName
        )
    }

    private func extractFormulaNames(from text: String) -> [String] {
        var names: [String] = []
        let lines = text.split(separator: "\n")
        var inList = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            if lower.contains("run `brew link` on these") || lower.contains("brew link on these") {
                inList = true
                continue
            }
            if inList {
                if trimmed.isEmpty || trimmed.contains(" ") || trimmed.hasPrefix("Warning") {
                    break
                }
                names.append(trimmed)
            } else if !trimmed.isEmpty && !trimmed.contains(" ") && !trimmed.hasPrefix("Warning") && !trimmed.hasPrefix("Run") && !trimmed.hasPrefix("Error") && !trimmed.contains(":") {
                names.append(trimmed)
            }
        }
        return names
    }

    private func extractCommandsFromRawOutput(_ raw: String) -> [String] {
        var commands: [String] = []
        let lines = raw.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("brew ") {
                commands.append(trimmed)
            } else if let backtickStart = trimmed.range(of: "`brew ") {
                let remainder = trimmed[backtickStart.upperBound...]
                if let backtickEnd = remainder.range(of: "`") {
                    let cmd = "brew " + remainder[..<backtickEnd.lowerBound]
                    commands.append(String(cmd))
                }
            }
        }
        let cleanCommands = commands.map { cmd -> String in
            var c = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
            if c.hasSuffix(".") { c.removeLast() }
            return c
        }.filter { !$0.isEmpty }

        return cleanCommands.isEmpty ? ["brew doctor"] : cleanCommands
    }

    // MARK: - Semantic Natural Language Discovery

    public func semanticSearch(query: String, catalogue: [BrewPackage], limit: Int) async -> [AISemanticSearchResult] {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        let queryTokens = normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }

        var results: [AISemanticSearchResult] = []

        for package in catalogue {
            let name = package.name.lowercased()
            let desc = package.description.lowercased()
            var score = 0.0
            var matchedKeywords: [String] = []

            // Direct substring matches
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

            // Keyword token matching
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

            // Capability / Intent heuristics
            if normalized.contains("image") && (name.contains("image") || desc.contains("image") || desc.contains("graphics") || name.contains("vips") || name.contains("magick")) {
                score += 0.5
                matchedKeywords.append("image capability")
            }
            if (normalized.contains("json") || normalized.contains("yaml")) && (desc.contains("json") || desc.contains("yaml") || desc.contains("parse") || desc.contains("processor")) {
                score += 0.5
                matchedKeywords.append("data formatting capability")
            }
            if normalized.contains("monitor") && (desc.contains("monitor") || desc.contains("process viewer") || desc.contains("system")) {
                score += 0.5
                matchedKeywords.append("system monitoring")
            }
            if (normalized.contains("fast") || normalized.contains("rust")) && (desc.contains("rust") || desc.contains("blazing fast") || desc.contains("replacement")) {
                score += 0.4
                matchedKeywords.append("modern tool replacement")
            }
            if (normalized.contains("git") || normalized.contains("vcs")) && (desc.contains("git") || desc.contains("version control")) {
                score += 0.5
                matchedKeywords.append("version control")
            }

            if score > 0.3 {
                let reason = matchedKeywords.isEmpty
                    ? "Relevant match for “\(query)”"
                    : "Matched via \(matchedKeywords.prefix(3).joined(separator: ", "))"
                results.append(
                    AISemanticSearchResult(
                        package: package,
                        relevanceScore: min(score, 1.0),
                        matchReason: reason
                    )
                )
            }
        }

        results.sort { $0.relevanceScore > $1.relevanceScore }
        return Array(results.prefix(limit))
    }

    // MARK: - Upgrade Impact Assessment

    public func assessUpgradeImpact(
        package: InstalledBrewPackage,
        targetVersion: String,
        dependents: [String]
    ) async -> AIUpgradeImpact {
        let currentVersion = package.installedVersions.first ?? "1.0.0"
        let isMajor = isMajorBump(current: currentVersion, target: targetVersion)

        let risk: AIRiskLevel
        if isMajor && !dependents.isEmpty {
            risk = .high
        } else if isMajor || dependents.count >= 2 {
            risk = .medium
        } else {
            risk = .low
        }

        var summary = "\(package.name) will upgrade from v\(currentVersion) to v\(targetVersion)."
        var breakingWarning: String?
        var serviceNotice: String?
        var verifyCommands: [String] = ["brew test \(package.name)"]

        if isMajor {
            summary += " This is a major version release that may include breaking interface changes."
            if !dependents.isEmpty {
                breakingWarning = "The following \(dependents.count) package(s) depend on \(package.name) and could experience compatibility issues: \(dependents.prefix(4).joined(separator: ", "))"
                verifyCommands.append(contentsOf: dependents.prefix(2).map { "brew test \($0)" })
            }
        } else if !dependents.isEmpty {
            summary += " \(dependents.count) installed packages rely on this package as a dependency."
        }

        let daemonPackages = ["redis", "postgresql", "mysql", "nginx", "dnsmasq", "mongodb-community", "mariadb", "httpd"]
        if daemonPackages.contains(package.name.lowercased()) {
            serviceNotice = "This package runs background daemons. You should restart the service after upgrading."
            verifyCommands.append("brew services restart \(package.name)")
        }

        return AIUpgradeImpact(
            packageName: package.name,
            currentVersion: currentVersion,
            targetVersion: targetVersion,
            riskLevel: risk,
            isMajorVersionBump: isMajor,
            affectedDependents: dependents,
            summary: summary,
            breakingChangesWarning: breakingWarning,
            serviceRestartNotice: serviceNotice,
            recommendedVerificationCommands: verifyCommands
        )
    }

    private func isMajorBump(current: String, target: String) -> Bool {
        let curMajor = current.prefix(while: { $0.isNumber })
        let tgtMajor = target.prefix(while: { $0.isNumber })
        guard !curMajor.isEmpty, !tgtMajor.isEmpty else { return false }
        return curMajor != tgtMajor
    }

    // MARK: - Brewfile & Environment Generator

    public func generateBrewfileEnvironment(prompt: String) async -> AIBrewfileEnvironment {
        let lower = prompt.lowercased()

        var title = "Custom Development Stack"
        var formulae: [String] = ["git", "curl"]
        var casks: [String] = []
        var taps: [String] = ["homebrew/core", "homebrew/cask"]
        var explanation = "Tailored Brewfile configuration generated for your workflow."

        if lower.contains("web") || lower.contains("node") || lower.contains("react") || lower.contains("typescript") {
            title = "Modern Fullstack Web Stack"
            formulae.append(contentsOf: ["node", "pnpm", "yarn", "gh"])
            casks.append(contentsOf: ["visual-studio-code", "google-chrome", "postman"])
            explanation = "Node.js ecosystem toolchain with package managers, Git CLI, and development runtime."
        } else if lower.contains("python") || lower.contains("data") || lower.contains("ai") || lower.contains("ml") {
            title = "Python Data & Machine Learning Stack"
            formulae.append(contentsOf: ["python@3.12", "uv", "ffmpeg", "libomp"])
            casks.append(contentsOf: ["visual-studio-code", "jupyterlab"])
            explanation = "High-performance Python 3.12 environment with uv package runner and C/OMP acceleration libraries."
        } else if lower.contains("ios") || lower.contains("swift") || lower.contains("apple") || lower.contains("mobile") {
            title = "Apple Platform & Swift Engineering Stack"
            formulae.append(contentsOf: ["swiftlint", "swiftformat", "xcbeautify", "cocoapods"])
            casks.append(contentsOf: ["sf-symbols"])
            explanation = "Essential iOS/macOS developer toolchain for Swift linting, formatting, and Xcode build log beautification."
        } else if lower.contains("devops") || lower.contains("cloud") || lower.contains("docker") || lower.contains("k8s") {
            title = "DevOps, Cloud & Infrastructure Stack"
            formulae.append(contentsOf: ["docker", "kubernetes-cli", "helm", "terraform", "awscli"])
            casks.append(contentsOf: ["docker"])
            explanation = "Containerization, cluster management, and Infrastructure-as-Code utilities."
        } else if lower.contains("rust") || lower.contains("systems") || lower.contains("terminal") {
            title = "Modern CLI & Rust Power Tools"
            formulae.append(contentsOf: ["rustup-init", "ripgrep", "bat", "eza", "fd", "starship", "fzf"])
            casks.append(contentsOf: ["iterm2"])
            explanation = "Blazing-fast modern command-line tools replacing legacy coreutils with Rust alternatives."
        } else {
            // General balanced setup
            formulae.append(contentsOf: ["ripgrep", "jq", "gh", "tree"])
            casks.append(contentsOf: ["visual-studio-code"])
        }

        // Deduplicate
        formulae = Array(NSOrderedSet(array: formulae)).compactMap { $0 as? String }
        casks = Array(NSOrderedSet(array: casks)).compactMap { $0 as? String }

        var lines: [String] = []
        lines.append("# Generated by Homebrew AI Environment Architect")
        lines.append("# Prompt: \"\(prompt)\"")
        lines.append("")
        for tap in taps {
            lines.append("tap \"\(tap)\"")
        }
        lines.append("")
        for formula in formulae {
            lines.append("brew \"\(formula)\"")
        }
        if !casks.isEmpty {
            lines.append("")
            for cask in casks {
                lines.append("cask \"\(cask)\"")
            }
        }

        let content = lines.joined(separator: "\n") + "\n"

        return AIBrewfileEnvironment(
            title: title,
            prompt: prompt,
            taps: taps,
            formulae: formulae,
            casks: casks,
            generatedBrewfileContent: content,
            bundleCommand: "brew bundle --file=Brewfile",
            explanation: explanation
        )
    }

    // MARK: - Smart Housekeeping & Orphan Detection

    public func assessHousekeeping(
        installedPackages: [InstalledBrewPackage],
        leaves: [String]
    ) async -> AIHousekeepingReport {
        var orphans: [AIOrphanCandidate] = []

        for leaf in leaves {
            if let pkg = installedPackages.first(where: { $0.name == leaf }) {
                let ver = pkg.installedVersions.first ?? "installed"
                // Categorize based on common developer tools vs transitive libraries
                let commonTopLevelTools = ["git", "node", "python", "ripgrep", "neovim", "tmux", "zsh", "docker", "gh"]
                let isCommonTool = commonTopLevelTools.contains(where: { leaf.lowercased().contains($0) })

                orphans.append(
                    AIOrphanCandidate(
                        packageName: leaf,
                        installedVersion: ver,
                        reason: isCommonTool
                            ? "Top-level formula with no dependent packages; safe to keep if you use it directly."
                            : "Installed leaf package with no dependents. May have been installed as a transitive dependency of an uninstalled formula.",
                        safetyLevel: isCommonTool ? .reviewRecommended : .safeToPrune
                    )
                )
            }
        }

        let safeCount = orphans.filter { $0.safetyLevel == .safeToPrune }.count
        let estMB = safeCount * 85
        let reclaimable = estMB >= 1000 ? String(format: "%.1f GB", Double(estMB) / 1000.0) : "\(estMB) MB"

        return AIHousekeepingReport(
            orphanCandidates: orphans,
            summary: "Identified \(orphans.count) leaf package(s) on your system. \(safeCount) can be safely pruned to reclaim disk space.",
            recommendedCommands: ["brew autoremove --dry-run", "brew cleanup -s"],
            reclaimableEstimate: reclaimable
        )
    }

    // MARK: - Modern Alternatives & Complements

    public func suggestAlternatives(for package: BrewPackage) async -> [AIPackageAlternative] {
        let name = package.name.lowercased()
        var results: [AIPackageAlternative] = []

        let catalog: [String: [AIPackageAlternative]] = [
            "grep": [
                AIPackageAlternative(
                    name: "ripgrep",
                    relationship: "Modern Rust Replacement",
                    headline: "Blazing fast search that respects .gitignore and skips binary files automatically",
                    keyAdvantages: [
                        "Up to 10x faster execution using multi-threaded SIMD acceleration",
                        "Automatically ignores hidden files and .gitignore patterns",
                        "Full Unicode support with coloured matched output"
                    ],
                    installCommand: "brew install ripgrep"
                ),
                AIPackageAlternative(
                    name: "ugrep",
                    relationship: "Feature-Rich Alternative",
                    headline: "Ultra-fast grep with interactive query UI and archive scanning",
                    keyAdvantages: [
                        "Built-in TUI query browser for live regex refinement",
                        "Searches inside zip, tar, and compressed archives directly",
                        "Compatibility with GNU/BSD grep flags"
                    ],
                    installCommand: "brew install ugrep"
                )
            ],
            "ripgrep": [
                AIPackageAlternative(
                    name: "fd",
                    relationship: "Recommended File-Finding Complement",
                    headline: "Fast, intuitive replacement for find that pairs seamlessly with ripgrep",
                    keyAdvantages: [
                        "Search file names and paths as quickly as ripgrep searches file contents",
                        "Colourised output matching file types",
                        "Simple, human-friendly regex syntax"
                    ],
                    installCommand: "brew install fd"
                ),
                AIPackageAlternative(
                    name: "bat",
                    relationship: "Recommended File-Viewing Complement",
                    headline: "Cat clone with syntax highlighting to inspect matching files",
                    keyAdvantages: [
                        "Syntax highlights code across 200+ languages",
                        "Integrated Git diff indicators in gutter",
                        "Automatic paging for long files"
                    ],
                    installCommand: "brew install bat"
                ),
                AIPackageAlternative(
                    name: "fzf",
                    relationship: "Interactive Fuzzy Matching Complement",
                    headline: "Interactive command-line fuzzy finder for files, history, and processes",
                    keyAdvantages: [
                        "Real-time interactive fuzzy searching",
                        "Terminal keyboard shortcuts (Ctrl+R, Ctrl+T)",
                        "Pipes ripgrep results directly into fuzzy picker"
                    ],
                    installCommand: "brew install fzf"
                )
            ],
            "cat": [
                AIPackageAlternative(
                    name: "bat",
                    relationship: "Modern Rust Replacement",
                    headline: "Cat clone with syntax highlighting, Git integration, and line numbers",
                    keyAdvantages: [
                        "Syntax highlighting for virtually every programming language",
                        "Gutter markers showing Git additions and modifications",
                        "Automatic paging when output exceeds screen height"
                    ],
                    installCommand: "brew install bat"
                )
            ],
            "find": [
                AIPackageAlternative(
                    name: "fd",
                    relationship: "Modern Rust Replacement",
                    headline: "Simple, fast, and user-friendly alternative to find",
                    keyAdvantages: [
                        "2x to 5x faster directory traversal than standard find",
                        "Respects .gitignore rules by default",
                        "Intuitive syntax without needing -name or complex flags"
                    ],
                    installCommand: "brew install fd"
                )
            ],
            "ls": [
                AIPackageAlternative(
                    name: "eza",
                    relationship: "Modern Rust Replacement",
                    headline: "Modern, feature-rich replacement for ls with colours and icons",
                    keyAdvantages: [
                        "Built-in tree view (-T) replacing the need for tree",
                        "Direct Git status column for tracked directories",
                        "Human-readable metadata and colour-coded permissions"
                    ],
                    installCommand: "brew install eza"
                )
            ],
            "top": [
                AIPackageAlternative(
                    name: "btop",
                    relationship: "Modern Visual Replacement",
                    headline: "Resource monitor that shows usage and stats for processor, memory, disks, and network",
                    keyAdvantages: [
                        "Beautiful terminal graphs with responsive mouse support",
                        "Detailed process tree with easy filtering and kill shortcuts",
                        "Per-core CPU, disk I/O, and GPU temperature monitoring"
                    ],
                    installCommand: "brew install btop"
                ),
                AIPackageAlternative(
                    name: "htop",
                    relationship: "Interactive Classic Replacement",
                    headline: "Classic interactive process viewer and text-mode system monitor",
                    keyAdvantages: [
                        "Colourful visual metres for CPU cores and memory",
                        "Scroll horizontally and vertically through process list",
                        "Extremely low CPU and memory overhead"
                    ],
                    installCommand: "brew install htop"
                )
            ],
            "htop": [
                AIPackageAlternative(
                    name: "btop",
                    relationship: "Next-Gen Visual Upgrade",
                    headline: "Modern C++ monitor with game-like visual graphs and mouse navigation",
                    keyAdvantages: [
                        "Rich real-time network and disk throughput graphs",
                        "Full mouse click and scroll support in the terminal",
                        "Highly customisable themes and layout panels"
                    ],
                    installCommand: "brew install btop"
                )
            ],
            "curl": [
                AIPackageAlternative(
                    name: "httpie",
                    relationship: "User-Friendly CLI Alternative",
                    headline: "Modern, user-friendly command-line HTTP client for API debugging",
                    keyAdvantages: [
                        "Formatted and colourised JSON responses automatically",
                        "Simple, intuitive syntax for query params, headers, and form data",
                        "Persistent sessions and built-in authentication support"
                    ],
                    installCommand: "brew install httpie"
                ),
                AIPackageAlternative(
                    name: "curlie",
                    relationship: "Hybrid Alternative",
                    headline: "The power of curl with the ease of use of HTTPie",
                    keyAdvantages: [
                        "Uses curl under the hood with all curl options supported",
                        "Prints colourised, formatted output like HTTPie",
                        "Great for scripts needing curl reliability with human readability"
                    ],
                    installCommand: "brew install curlie"
                )
            ],
            "sed": [
                AIPackageAlternative(
                    name: "sd",
                    relationship: "Modern Rust Replacement",
                    headline: "Intuitive find & replace CLI with standard regular expressions",
                    keyAdvantages: [
                        "Standard regex syntax without escaping slashes or brackets",
                        "Much faster in-place file modifications (-i)",
                        "Clear error reporting and preview before write"
                    ],
                    installCommand: "brew install sd"
                )
            ],
            "diff": [
                AIPackageAlternative(
                    name: "difftastic",
                    relationship: "AST-Aware Structural Diff",
                    headline: "Syntax-aware diff that compares code by structure rather than lines",
                    keyAdvantages: [
                        "Understands programming language grammar via Tree-sitter",
                        "Ignores insignificant formatting and whitespace differences",
                        "Highlights exact semantic modifications within expressions"
                    ],
                    installCommand: "brew install difftastic"
                ),
                AIPackageAlternative(
                    name: "delta",
                    relationship: "Modern Git Pager",
                    headline: "Syntax-highlighting pager for git, diff, and grep output",
                    keyAdvantages: [
                        "Side-by-side or unified diffs with 24-bit colour palettes",
                        "Shows line numbers and word-level character diffs",
                        "Integrates smoothly into ~/.gitconfig"
                    ],
                    installCommand: "brew install git-delta"
                )
            ],
            "du": [
                AIPackageAlternative(
                    name: "dust",
                    relationship: "Intuitive Rust Replacement",
                    headline: "A more graphical and intuitive du for visualising disk usage",
                    keyAdvantages: [
                        "Renders bar-chart tree showing which folders consume storage",
                        "Sorted automatically by descending size",
                        "Fast multi-threaded filesystem scan"
                    ],
                    installCommand: "brew install dust"
                )
            ],
            "docker": [
                AIPackageAlternative(
                    name: "orbstack",
                    relationship: "Lightweight Native Alternative",
                    headline: "Fast, light, and simple way to run Docker containers and Linux machines",
                    keyAdvantages: [
                        "Instant startup with a fraction of Docker Desktop's memory usage",
                        "Up to 2x faster build and volume read/write performance",
                        "Minimal battery consumption on Apple Silicon"
                    ],
                    installCommand: "brew install --cask orbstack",
                    isFormula: false
                ),
                AIPackageAlternative(
                    name: "colima",
                    relationship: "Open Source Container Runtime",
                    headline: "Container runtimes on macOS with minimal setup via Lima",
                    keyAdvantages: [
                        "Free and open-source command-line container environment",
                        "Supports both Docker and Kubernetes runtimes",
                        "Configurable CPU, RAM, and disk allocations"
                    ],
                    installCommand: "brew install colima"
                )
            ],
            "iterm2": [
                AIPackageAlternative(
                    name: "ghostty",
                    relationship: "Fast Native Terminal",
                    headline: "GPU-accelerated terminal emulator designed for macOS",
                    keyAdvantages: [
                        "Sub-millisecond input latency powered by Metal",
                        "Native macOS user interface with tabs and split panes",
                        "Rich font rendering with ligatures and Kitty graphics protocol"
                    ],
                    installCommand: "brew install --cask ghostty",
                    isFormula: false
                ),
                AIPackageAlternative(
                    name: "alacritty",
                    relationship: "Minimalist High-Speed Terminal",
                    headline: "Cross-platform, GPU-accelerated terminal emulator written in Rust",
                    keyAdvantages: [
                        "Extreme rendering performance and low memory footprint",
                        "Configured via simple TOML file",
                        "Focused on speed without unnecessary bloat"
                    ],
                    installCommand: "brew install --cask alacritty",
                    isFormula: false
                )
            ],
            "vim": [
                AIPackageAlternative(
                    name: "neovim",
                    relationship: "Modern Extensible Evolution",
                    headline: "Vim-fork focused on extensibility, Lua scripting, and modern LSP",
                    keyAdvantages: [
                        "Built-in Language Server Protocol (LSP) client",
                        "First-class Lua configuration and plugin ecosystem",
                        "Async job control and modern terminal integration"
                    ],
                    installCommand: "brew install neovim"
                )
            ],
            "python": [
                AIPackageAlternative(
                    name: "uv",
                    relationship: "Ultra-Fast Package Manager",
                    headline: "Extremely fast Python package and project manager written in Rust",
                    keyAdvantages: [
                        "10x to 100x faster than pip and pip-tools",
                        "Replaces pip, virtualenv, poetry, and pyenv in one single binary",
                        "Global caching with zero redundant disk downloads"
                    ],
                    installCommand: "brew install uv"
                )
            ]
        ]

        if let matches = catalog[name] {
            results.append(contentsOf: matches)
        } else {
            // Fuzzy / category match fallback
            if name.contains("python") {
                results.append(
                    AIPackageAlternative(
                        name: "uv",
                        relationship: "Ultra-Fast Package Manager",
                        headline: "Extremely fast Python package and project manager written in Rust",
                        keyAdvantages: [
                            "10x to 100x faster than pip and pip-tools",
                            "Universal virtual environment and tool runner",
                            "Native single-binary workflow"
                        ],
                        installCommand: "brew install uv"
                    )
                )
            } else if name.contains("git") && name != "lazygit" {
                results.append(
                    AIPackageAlternative(
                        name: "lazygit",
                        relationship: "Visual Terminal UI",
                        headline: "Simple terminal UI for git commands that simplifies staging and rebasing",
                        keyAdvantages: [
                            "Interactive visual hunk and line staging",
                            "One-key interactive rebasing, squash, and commit amending",
                            "Visual branch and stash navigator"
                        ],
                        installCommand: "brew install lazygit"
                    )
                )
            }
        }

        return results
    }

    // MARK: - Personalized Machine Recommendations

    public func recommendPackages(
        basedOn installedPackages: [InstalledBrewPackage]
    ) async -> [AIPackageRecommendation] {
        let installedNames = Set(installedPackages.map { $0.name.lowercased() })
        var recommendations: [AIPackageRecommendation] = []

        // Rule 1: Git workflow enhancers
        let hasGit = installedNames.contains("git") || installedNames.contains(where: { $0.contains("git") })
        if hasGit {
            if !installedNames.contains("lazygit") {
                recommendations.append(
                    AIPackageRecommendation(
                        packageName: "lazygit",
                        category: "Git & Source Control",
                        reason: "You use Git. Lazygit provides an interactive terminal UI for rapid staging, rebasing, and branch navigation.",
                        confidenceScore: 0.96
                    )
                )
            }
            if !installedNames.contains("gh") {
                recommendations.append(
                    AIPackageRecommendation(
                        packageName: "gh",
                        category: "Git & Source Control",
                        reason: "Official GitHub CLI tool to review pull requests, create releases, and manage issues directly from your terminal.",
                        confidenceScore: 0.94
                    )
                )
            }
            if !installedNames.contains("git-delta") && !installedNames.contains("delta") {
                recommendations.append(
                    AIPackageRecommendation(
                        packageName: "git-delta",
                        category: "Git & Source Control",
                        reason: "Syntax-highlighting pager for git diffs with side-by-side view and word-level diffing.",
                        confidenceScore: 0.88
                    )
                )
            }
        }

        // Rule 2: Rust / Modern CLI Power Pack
        if !installedNames.contains("ripgrep") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "ripgrep",
                    category: "CLI Power Tools",
                    reason: "Top-tier search utility that searches codebases up to 10x faster than standard grep.",
                    confidenceScore: 0.98
                )
            )
        }
        if !installedNames.contains("bat") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "bat",
                    category: "CLI Power Tools",
                    reason: "Modern replacement for cat with syntax highlighting for 200+ languages and git gutter marks.",
                    confidenceScore: 0.95
                )
            )
        }
        if !installedNames.contains("eza") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "eza",
                    category: "CLI Power Tools",
                    reason: "Modern replacement for ls with colours, file icons, git status, and tree views.",
                    confidenceScore: 0.92
                )
            )
        }
        if !installedNames.contains("zoxide") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "zoxide",
                    category: "CLI Navigation",
                    reason: "Smarter cd command that learns your most frequent directories for instantaneous jumping.",
                    confidenceScore: 0.90
                )
            )
        }

        // Rule 3: Python development
        let hasPython = installedNames.contains(where: { $0.contains("python") })
        if hasPython && !installedNames.contains("uv") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "uv",
                    category: "Python Tooling",
                    reason: "Extremely fast Python package installer and resolver that accelerates pip and virtual environment workflows.",
                    confidenceScore: 0.93
                )
            )
        }

        // Rule 4: System Monitoring
        if !installedNames.contains("btop") && !installedNames.contains("htop") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "btop",
                    category: "System Monitoring",
                    reason: "Visual terminal monitor showing real-time CPU, memory, disk, and network throughput with mouse support.",
                    confidenceScore: 0.89
                )
            )
        }

        // Rule 5: Container & DevOps
        let hasContainers = installedNames.contains("docker") || installedNames.contains("colima") || installedNames.contains("kubernetes-cli")
        if hasContainers {
            if !installedNames.contains("lazydocker") {
                recommendations.append(
                    AIPackageRecommendation(
                        packageName: "lazydocker",
                        category: "DevOps & Containers",
                        reason: "Terminal UI for docker and docker-compose to inspect container logs, metrics, and manage restart cycles.",
                        confidenceScore: 0.91
                    )
                )
            }
            if !installedNames.contains("k9s") && installedNames.contains("kubernetes-cli") {
                recommendations.append(
                    AIPackageRecommendation(
                        packageName: "k9s",
                        category: "DevOps & Containers",
                        reason: "Terminal-based dashboard to navigate, observe, and manage Kubernetes clusters.",
                        confidenceScore: 0.92
                    )
                )
            }
        }

        // Rule 6: Productivity GUI Apps
        if !installedNames.contains("raycast") {
            recommendations.append(
                AIPackageRecommendation(
                    packageName: "raycast",
                    category: "macOS Productivity",
                    reason: "Fast, extensible launcher for macOS with clipboard history, window management, and developer extensions.",
                    confidenceScore: 0.87,
                    isCask: true
                )
            )
        }

        return recommendations
    }

    // MARK: - Side-by-Side Package Comparison

    public func comparePackages(
        packageA: BrewPackage,
        packageB: BrewPackage
    ) async -> AIPackageComparison {
        let nameA = packageA.displayName.lowercased()
        let nameB = packageB.displayName.lowercased()

        // Detect comparative strengths
        let strengthsA: [String]
        let strengthsB: [String]
        let bestForA: String
        let bestForB: String
        let verdict: String
        let matrix: [AIComparisonRow]

        if (nameA.contains("grep") && nameB.contains("ripgrep")) || (nameB.contains("grep") && nameA.contains("ripgrep")) {
            let isARipgrep = nameA.contains("ripgrep")
            let rgName = isARipgrep ? packageA.displayName : packageB.displayName
            let grepName = isARipgrep ? packageB.displayName : packageA.displayName

            verdict = "\(rgName) is vastly superior for modern software development and interactive shell use, running up to 10x faster and automatically filtering non-code files."
            let rgStrengths = [
                "Exceptional search speed via multi-threaded Rust SIMD regex",
                "Automatically respects .gitignore and skips binary files",
                "Rich colourised syntax output with Unicode support"
            ]
            let grepStrengths = [
                "Standard POSIX utility pre-installed on virtually all Unix systems",
                "Strict adherence to traditional command-line flags in legacy scripts",
                "Zero external runtime dependencies"
            ]
            strengthsA = isARipgrep ? rgStrengths : grepStrengths
            strengthsB = isARipgrep ? grepStrengths : rgStrengths
            bestForA = isARipgrep ? "Interactive terminal searches and large source code repositories" : "Legacy shell scripts requiring standard POSIX conformity"
            bestForB = isARipgrep ? "Legacy shell scripts requiring standard POSIX conformity" : "Interactive terminal searches and large source code repositories"

            matrix = [
                AIComparisonRow(
                    feature: "Speed & Performance",
                    packageAValue: isARipgrep ? "Multi-threaded SIMD (10x faster)" : "Single-threaded linear scan",
                    packageBValue: isARipgrep ? "Single-threaded linear scan" : "Multi-threaded SIMD (10x faster)"
                ),
                AIComparisonRow(
                    feature: "Git Integration",
                    packageAValue: isARipgrep ? "Respects .gitignore by default" : "None (requires manual prune flags)",
                    packageBValue: isARipgrep ? "None (requires manual prune flags)" : "Respects .gitignore by default"
                ),
                AIComparisonRow(
                    feature: "Binary Files",
                    packageAValue: isARipgrep ? "Automatically skipped" : "Scanned unless -I is specified",
                    packageBValue: isARipgrep ? "Scanned unless -I is specified" : "Automatically skipped"
                ),
                AIComparisonRow(
                    feature: "Portability",
                    packageAValue: isARipgrep ? "Requires Homebrew/Cargo binary" : "Ubiquitous on all Unix systems",
                    packageBValue: isARipgrep ? "Ubiquitous on all Unix systems" : "Requires Homebrew/Cargo binary"
                )
            ]
        } else {
            // General comparative synthesis
            let kindA = packageA.kind == .cask ? "GUI Application" : "CLI Utility"
            let kindB = packageB.kind == .cask ? "GUI Application" : "CLI Utility"

            verdict = "Both \(packageA.displayName) and \(packageB.displayName) are high-quality Homebrew packages. Selection depends primarily on your preferred workflow and resource requirements."
            strengthsA = [
                "Dedicated \(packageA.displayName) feature set and mature configuration options",
                "Clear documentation and stable release cadence",
                "Streamlined for \(packageA.name) workflows"
            ]
            strengthsB = [
                "Focused on \(packageB.displayName) paradigms and performance",
                "Modern architecture with active community maintenance",
                "Seamless integration with contemporary macOS tooling"
            ]
            bestForA = "Users prioritising established stability and customisation within \(packageA.displayName)"
            bestForB = "Users looking for modern ergonomics and capabilities in \(packageB.displayName)"

            matrix = [
                AIComparisonRow(feature: "Package Type", packageAValue: kindA, packageBValue: kindB),
                AIComparisonRow(feature: "Latest Version", packageAValue: packageA.latestVersion, packageBValue: packageB.latestVersion),
                AIComparisonRow(
                    feature: "Dependencies",
                    packageAValue: "\(packageA.dependencies.count) direct dependencies",
                    packageBValue: "\(packageB.dependencies.count) direct dependencies"
                ),
                AIComparisonRow(
                    feature: "Homepage",
                    packageAValue: packageA.homepage.isEmpty ? "Not listed" : "Official portal available",
                    packageBValue: packageB.homepage.isEmpty ? "Not listed" : "Official portal available"
                )
            ]
        }

        return AIPackageComparison(
            packageAName: packageA.displayName,
            packageBName: packageB.displayName,
            verdictSummary: verdict,
            strengthsA: strengthsA,
            strengthsB: strengthsB,
            bestForA: bestForA,
            bestForB: bestForB,
            matrix: matrix
        )
    }
}
