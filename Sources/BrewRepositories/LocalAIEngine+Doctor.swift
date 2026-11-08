//
//  LocalAIEngine+Doctor.swift
//  BrewRepositories
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation

extension LocalAIEngine {
    // MARK: - Doctor Diagnostics Analysis

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
                formulaNames.map { "brew link \($0)" }
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

    private func extractFormulaNames(from text: String) -> [String] {
        var names: [String] = []
        let lines = text.split(separator: "\n")
        var inList = false
        for line in lines {
            let trimmed = cleanCandidateLine(line)
            let lower = trimmed.lowercased()
            if lower.contains("run `brew link` on these") || lower.contains("brew link on these") {
                inList = true
                continue
            }
            if trimmed.isEmpty {
                if !names.isEmpty {
                    break
                }
                continue
            }
            guard isValidFormulaName(trimmed) else {
                if inList, !names.isEmpty {
                    break
                }
                continue
            }
            if !names.contains(trimmed) {
                names.append(trimmed)
            }
        }
        return names
    }

    private func cleanCandidateLine(_ line: Substring) -> String {
        var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("`") && trimmed.hasSuffix("`") && trimmed.count > 1 {
            trimmed = String(trimmed.dropFirst().dropLast())
        }
        if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
            trimmed = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }

    private func isValidFormulaName(_ name: String) -> Bool {
        guard !name.isEmpty,
              name.count <= 128,
              !name.contains("/"),
              !name.contains("\\"),
              !name.contains(":"),
              !name.contains(" ")
        else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "+._@-"))
        guard name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        guard let first = name.unicodeScalars.first, CharacterSet.alphanumerics.contains(first) else { return false }
        return true
    }
}
