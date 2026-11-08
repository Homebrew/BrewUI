//
//  LocalAIEngine.swift
//  BrewRepositories
//
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

    private func resolveEngineName() async -> String {
        let (activeModelID, availableModels) = await MainActor.run {
            (modelManager.activeModelID, modelManager.availableModels)
        }
        let activeModel = availableModels.first(where: { $0.id == activeModelID })
        return activeModel?.name ?? "Local Expert Engine"
    }

    public func analyzeDoctorIssue(title: String, rawOutput: String) async -> AIAnalysisResult {
        let engineName = await resolveEngineName()
        let lower = (title + " " + rawOutput).lowercased()

        if let specific = matchSpecificDoctorIssue(lower: lower, rawOutput: rawOutput, engineName: engineName) {
            return specific
        }

        return AIAnalysisResult(
            summary: "Homebrew detected a system configuration anomaly: \(title.trimmingCharacters(in: .whitespacesAndNewlines)).",
            rootCause: "Your local environment diverges from Homebrew's recommended defaults.",
            suggestedCommands: extractCommandsFromRawOutput(rawOutput),
            modelName: engineName,
        )
    }

    private func matchSpecificDoctorIssue(lower: String, rawOutput: String, engineName: String) -> AIAnalysisResult? {
        if lower.contains("unlinked kegs") || lower.contains("not linked") {
            let formulaNames = extractFormulaNames(from: rawOutput)
            let commands: [String] = if !formulaNames.isEmpty {
                formulaNames.map { "brew link --overwrite \($0)" }
            } else {
                ["brew doctor"]
            }
            let summarySubject = formulaNames.isEmpty ? "one or more packages" : formulaNames.joined(separator: ", ")
            return AIAnalysisResult(
                summary: "Homebrew installed the files for \(summarySubject), but its command-line binaries "
                    + "were not symlinked into your bin directory, making them inaccessible.",
                rootCause: "A prior install was interrupted or another software package conflicted with existing symlinks.",
                suggestedCommands: commands,
                modelName: engineName,
            )
        }

        if lower.contains("broken symlinks") || lower.contains("dangling symlinks") {
            return AIAnalysisResult(
                summary: "You have obsolete file pointers in your Homebrew prefix pointing to files that no longer exist.",
                rootCause: "Old versions or uninstalled formulae left dead references behind in the directory tree.",
                suggestedCommands: ["brew cleanup -s", "brew doctor"],
                modelName: engineName,
            )
        }

        if lower.contains("clt") || lower.contains("command line tools") || lower.contains("xcode") {
            return AIAnalysisResult(
                summary: "Your Apple Xcode Command Line Tools are missing, incomplete, or out of sync with your current macOS version.",
                rootCause: "A macOS system update changed developer paths or the SDK headers are not installed.",
                suggestedCommands: ["xcode-select --install", "sudo xcode-select --reset"],
                modelName: engineName,
            )
        }

        if lower.contains("config-scripts") || lower.contains("*-config") {
            return AIAnalysisResult(
                summary: "Third-party configuration scripts are in your PATH ahead of Homebrew, "
                    + "which can cause compile-time conflicts when building formulae.",
                rootCause: "Other package managers or standalone SDKs modified your shell search order.",
                suggestedCommands: ["brew doctor"],
                modelName: engineName,
            )
        }

        return nil
    }

    public func analyzeCommandFailure(command: String, exitCode: Int, output: String) async -> AIAnalysisResult {
        let engineName = await resolveEngineName()
        let lower = output.lowercased()

        let args = command.split(separator: " ").map(String.init)
        let isCask = args.contains("--cask")
        let pkg = args.dropFirst(2).reversed().first(where: { !$0.hasPrefix("-") }) ?? ""
        let caskFlag = isCask ? "--cask " : ""

        if let specific = matchSpecificCommandFailure(lower: lower, pkg: pkg, caskFlag: caskFlag, isCask: isCask, engineName: engineName) {
            return specific
        }

        return AIAnalysisResult(
            summary: "Command `\(command)` terminated unexpectedly with exit code \(exitCode).",
            rootCause: "An error occurred during process execution. Inspect the stderr logs for diagnostic traces.",
            suggestedCommands: ["brew doctor", "brew update"],
            modelName: engineName,
        )
    }

    private func matchSpecificCommandFailure(
        lower: String,
        pkg: String,
        caskFlag: String,
        isCask: Bool,
        engineName: String,
    ) -> AIAnalysisResult? {
        if lower.contains("checksum mismatch") || lower.contains("sha256") {
            let fetchCmd = pkg.isEmpty ? "brew update" : "brew fetch \(caskFlag)--force \(pkg)"
            return AIAnalysisResult(
                summary: "The downloaded file does not match the cryptographic checksum recorded in the Homebrew formula.",
                rootCause: "The upstream download was corrupted in transit, or the vendor released a silent patch with a new archive.",
                suggestedCommands: ["brew cleanup --prune=all", fetchCmd],
                modelName: engineName,
            )
        }

        if lower.contains("permission denied") || lower.contains("eacces") {
            return AIAnalysisResult(
                summary: "Homebrew was unable to write or modify a file because your user account lacks the required filesystem permissions.",
                rootCause: "Files inside the prefix or cask target were previously touched by root or another administrator account.",
                suggestedCommands: ["brew doctor"],
                modelName: engineName,
            )
        }

        if lower.contains("already installed") {
            let subject = pkg.isEmpty ? "The package" : "The package \(pkg)"
            let cmds = pkg.isEmpty ? ["brew doctor"] : ["brew reinstall \(caskFlag)\(pkg)", "brew upgrade \(caskFlag)\(pkg)"]
            return AIAnalysisResult(
                summary: "\(subject) is already present in your installed inventory.",
                rootCause: "Attempted to install an already installed package without specifying upgrade or reinstall.",
                suggestedCommands: cmds,
                modelName: engineName,
            )
        }

        if lower.contains("no bottle available") || lower.contains("pour failed") {
            let cmds = pkg.isEmpty ? ["brew doctor"] : (isCask ? ["brew reinstall --cask \(pkg)"] : ["brew install --build-from-source \(pkg)"])
            return AIAnalysisResult(
                summary: "A pre-compiled binary bottle is unavailable for your specific macOS or CPU architecture.",
                rootCause: "Homebrew requires building this formula from source code on your machine.",
                suggestedCommands: cmds,
                modelName: engineName,
            )
        }

        return nil
    }

    private func extractFormulaNames(from text: String) -> [String] {
        var names: [String] = []
        let lines = text.split(separator: "\n")
        var inList = false
        for line in lines {
            var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("`") && trimmed.hasSuffix("`") && trimmed.count > 1 {
                trimmed = String(trimmed.dropFirst().dropLast())
            }
            let lower = trimmed.lowercased()
            if lower.contains("run `brew link` on these") || lower.contains("brew link on these") {
                inList = true
                continue
            }
            if inList {
                if trimmed.isEmpty {
                    if names.isEmpty {
                        continue
                    } else {
                        break
                    }
                }
                if trimmed.contains(" ") || trimmed.hasPrefix("Warning") || trimmed.hasPrefix("Error") {
                    break
                }
                if !names.contains(trimmed) {
                    names.append(trimmed)
                }
            } else if !trimmed.isEmpty, !trimmed.contains(" "), !trimmed.hasPrefix("Warning"),
                      !trimmed.hasPrefix("Run"), !trimmed.hasPrefix("Error"), !trimmed.contains(":")
            {
                if !names.contains(trimmed) {
                    names.append(trimmed)
                }
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

    // MARK: - Upgrade Impact Assessment

    public func assessUpgradeImpact(
        package: InstalledBrewPackage,
        targetVersion: String,
        dependents: [String],
    ) async -> AIUpgradeImpact {
        let currentVersion = package.installedVersions.first ?? "1.0.0"
        let isMajor = isMajorBump(current: currentVersion, target: targetVersion)

        let risk: AIRiskLevel = if isMajor && !dependents.isEmpty {
            .high
        } else if isMajor || dependents.count >= 2 {
            .medium
        } else {
            .low
        }

        var summary = "\(package.name) will upgrade from v\(currentVersion) to v\(targetVersion)."
        var breakingWarning: String?
        var serviceNotice: String?
        var verifyCommands = package.package.kind == .cask ? [] : ["brew test \(package.name)"]

        if isMajor {
            summary += " This is a major version release that may include breaking interface changes."
            if !dependents.isEmpty {
                let depList = dependents.prefix(4).joined(separator: ", ")
                breakingWarning = "The following \(dependents.count) package(s) depend on \(package.name) "
                    + "and could experience compatibility issues: \(depList)"
                verifyCommands.append(contentsOf: dependents.prefix(2).map { "brew test \($0)" })
            }
        } else if !dependents.isEmpty {
            summary += " \(dependents.count) installed packages rely on this package as a dependency."
        }

        let daemonPackages = ["redis", "postgresql", "mysql", "nginx", "dnsmasq", "mongodb-community", "mariadb", "httpd"]
        let isDaemon = daemonPackages.contains(where: {
            let pkgLower = package.name.lowercased()
            return pkgLower == $0 || pkgLower.hasPrefix("\($0)@")
        })
        if isDaemon {
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
            recommendedVerificationCommands: verifyCommands,
        )
    }

    private func isMajorBump(current: String, target: String) -> Bool {
        let curDigits = current.drop(while: { !$0.isNumber })
        let tgtDigits = target.drop(while: { !$0.isNumber })
        let curMajor = curDigits.prefix(while: { $0.isNumber })
        let tgtMajor = tgtDigits.prefix(while: { $0.isNumber })
        guard !curMajor.isEmpty, !tgtMajor.isEmpty else { return false }
        return curMajor != tgtMajor
    }
}
