//
//  LocalAIEngine+Comparison.swift
//  BrewRepositories
//
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation

extension LocalAIEngine {
    // MARK: - Side-by-Side Package Comparison

    public func comparePackages(
        packageA: BrewPackage,
        packageB: BrewPackage,
    ) async -> AIPackageComparison {
        let nameA = packageA.displayName.lowercased()
        let nameB = packageB.displayName.lowercased()

        let isExactGrepPair = (nameA == "grep" && nameB == "ripgrep") || (nameA == "ripgrep" && nameB == "grep")
        if isExactGrepPair {
            return compareGrepVsRipgrep(packageA: packageA, packageB: packageB)
        } else {
            return generalPackageComparison(packageA: packageA, packageB: packageB)
        }
    }

    private func compareGrepVsRipgrep(packageA: BrewPackage, packageB: BrewPackage) -> AIPackageComparison {
        let nameA = packageA.displayName.lowercased()
        let isARipgrep = nameA.contains("ripgrep")
        let rgName = isARipgrep ? packageA.displayName : packageB.displayName

        let verdict = "\(rgName) is vastly superior for modern software development and interactive shell use, "
            + "running up to 10x faster and automatically filtering non-code files."
        let rgStrengths = [
            "Exceptional search speed via multi-threaded Rust SIMD regex",
            "Automatically respects .gitignore and skips binary files",
            "Rich colourised syntax output with Unicode support",
        ]
        let grepStrengths = [
            "Standard POSIX utility pre-installed on virtually all Unix systems",
            "Strict adherence to traditional command-line flags in legacy scripts",
            "Zero external runtime dependencies",
        ]

        let matrix = [
            AIComparisonRow(
                feature: "Speed & Performance",
                packageAValue: isARipgrep ? "Multi-threaded SIMD (10x faster)" : "Single-threaded linear scan",
                packageBValue: isARipgrep ? "Single-threaded linear scan" : "Multi-threaded SIMD (10x faster)",
            ),
            AIComparisonRow(
                feature: "Git Integration",
                packageAValue: isARipgrep ? "Respects .gitignore by default" : "None (requires manual prune flags)",
                packageBValue: isARipgrep ? "None (requires manual prune flags)" : "Respects .gitignore by default",
            ),
            AIComparisonRow(
                feature: "Binary Files",
                packageAValue: isARipgrep ? "Automatically skipped" : "Scanned unless -I is specified",
                packageBValue: isARipgrep ? "Scanned unless -I is specified" : "Automatically skipped",
            ),
            AIComparisonRow(
                feature: "Portability",
                packageAValue: isARipgrep ? "Requires Homebrew/Cargo binary" : "Ubiquitous on all Unix systems",
                packageBValue: isARipgrep ? "Ubiquitous on all Unix systems" : "Requires Homebrew/Cargo binary",
            ),
        ]

        return AIPackageComparison(
            packageAName: packageA.displayName,
            packageBName: packageB.displayName,
            verdictSummary: verdict,
            strengthsA: isARipgrep ? rgStrengths : grepStrengths,
            strengthsB: isARipgrep ? grepStrengths : rgStrengths,
            bestForA: isARipgrep ? "Interactive terminal searches and large source code repositories"
                : "Legacy shell scripts requiring standard POSIX conformity",
            bestForB: isARipgrep ? "Legacy shell scripts requiring standard POSIX conformity"
                : "Interactive terminal searches and large source code repositories",
            matrix: matrix,
        )
    }

    private func generalPackageComparison(packageA: BrewPackage, packageB: BrewPackage) -> AIPackageComparison {
        let kindA = packageA.kind == .cask ? "Cask" : "Formula"
        let kindB = packageB.kind == .cask ? "Cask" : "Formula"

        let verdict = "Both \(packageA.displayName) and \(packageB.displayName) are high-quality Homebrew packages. "
            + "Selection depends primarily on your preferred workflow and resource requirements."

        let strengthsA = packageStrengths(for: packageA)
        let strengthsB = packageStrengths(for: packageB)

        let bestForA = "Users opting for \(packageA.displayName) based on their specific ecosystem and workflow requirements."
        let bestForB = "Users opting for \(packageB.displayName) based on their specific ecosystem and workflow requirements."

        let versionA = packageA.latestVersion.isEmpty ? "Unknown" : packageA.latestVersion
        let versionB = packageB.latestVersion.isEmpty ? "Unknown" : packageB.latestVersion
        let matrix = [
            AIComparisonRow(feature: "Package Type", packageAValue: kindA, packageBValue: kindB),
            AIComparisonRow(feature: "Latest Version", packageAValue: versionA, packageBValue: versionB),
            AIComparisonRow(
                feature: "Dependencies",
                packageAValue: "\(packageA.dependencies.count) direct dependencies",
                packageBValue: "\(packageB.dependencies.count) direct dependencies",
            ),
            AIComparisonRow(
                feature: "Homepage",
                packageAValue: packageA.homepage.isEmpty ? "Not listed" : "Official portal available",
                packageBValue: packageB.homepage.isEmpty ? "Not listed" : "Official portal available",
            ),
        ]

        return AIPackageComparison(
            packageAName: packageA.displayName,
            packageBName: packageB.displayName,
            verdictSummary: verdict,
            strengthsA: strengthsA,
            strengthsB: strengthsB,
            bestForA: bestForA,
            bestForB: bestForB,
            matrix: matrix,
        )
    }

    private func packageStrengths(for package: BrewPackage) -> [String] {
        var strengths: [String] = []
        if package.kind == .cask {
            strengths.append("Native macOS graphical user interface application")
        } else {
            strengths.append("Command-line interface tool integrated with terminal workflows")
        }
        if package.dependencies.isEmpty {
            strengths.append("Standalone package with zero external dependencies")
        } else {
            strengths.append("Rich feature set with \(package.dependencies.count) direct dependencies")
        }
        if !package.homepage.isEmpty {
            strengths.append("Documented project with accessible developer portal")
        }
        return strengths
    }
}
