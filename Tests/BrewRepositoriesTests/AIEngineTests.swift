//
//  AIEngineTests.swift
//  BrewRepositoriesTests
//

import BrewCore
import BrewRepositories
import BrewRepositoryInterfaces
import Testing

@Suite("AIEngine")
struct AIEngineTests {
    private final class MockModelManager: AIModelManaging, @unchecked Sendable {
        let availableModels: [AIModelSpec] = AIModelCatalog.allModels
        var activeModelID: String? = AIModelCatalog.qwenCoder15B.id
        var hardwareProfile = AISystemHardwareProfile()

        func downloadState(for model: AIModelSpec) -> AIModelDownloadState { .ready }
        func setActiveModel(id: String?) { activeModelID = id }
        func startDownload(for model: AIModelSpec) async {}
        func cancelDownload(for model: AIModelSpec) {}
        func deleteModel(for model: AIModelSpec) {}
    }

    @Test func `engine identifies unlinked keg and generates link command`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let result = await engine.analyzeDoctorIssue(
            title: "You have unlinked kegs in your Cellar",
            rawOutput: "node\ngit"
        )

        #expect(result.summary.contains("symlinked"))
        #expect(result.suggestedCommands.contains { $0.contains("brew link") })
    }

    @Test func `engine identifies missing command line tools and suggests xcode-select`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let result = await engine.analyzeDoctorIssue(
            title: "Your Command Line Tools (CLT) does not appear to be installed",
            rawOutput: "A CLT error was detected"
        )

        #expect(result.suggestedCommands.contains("xcode-select --install"))
    }

    @Test func `engine explains checksum mismatch error`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let result = await engine.analyzeCommandFailure(
            command: "brew install ripgrep",
            exitCode: 1,
            output: "Error: SHA256 mismatch\nExpected: abc\nActual: def"
        )

        #expect(result.summary.contains("checksum"))
        #expect(result.suggestedCommands.contains { $0.contains("brew fetch --force") })
    }

    @Test func `engine performs semantic natural language search`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let packages: [BrewPackage] = [
            .fixture(name: "imagemagick", description: "Tools and libraries to manipulate images in many formats"),
            .fixture(name: "jq", description: "Lightweight and flexible command-line JSON processor"),
            .fixture(name: "btop", description: "Resource monitor that shows usage and stats"),
        ]

        let imageResults = await engine.semanticSearch(query: "resize and format image", catalogue: packages, limit: 10)
        #expect(!imageResults.isEmpty)
        #expect(imageResults.first?.package.name == "imagemagick")

        let jsonResults = await engine.semanticSearch(query: "parse json from terminal", catalogue: packages, limit: 10)
        #expect(!jsonResults.isEmpty)
        #expect(jsonResults.first?.package.name == "jq")
    }

    @Test func `engine assesses upgrade impact with major version bump and dependents`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let package = InstalledBrewPackage.fixture(name: "node", latestVersion: "22.2.0", installedVersions: ["20.11.0"])

        let impact = await engine.assessUpgradeImpact(
            package: package,
            targetVersion: "22.2.0",
            dependents: ["yarn", "pnpm"]
        )

        #expect(impact.riskLevel == .high)
        #expect(impact.isMajorVersionBump)
        #expect(impact.affectedDependents.count == 2)
        #expect(impact.breakingChangesWarning != nil)
    }

    @Test func `engine generates conversational Brewfile environment`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let env = await engine.generateBrewfileEnvironment(prompt: "Modern fullstack react and node setup")

        #expect(env.formulae.contains("node"))
        #expect(env.formulae.contains("pnpm"))
        #expect(env.generatedBrewfileContent.contains("brew \"node\""))
        #expect(env.bundleCommand.contains("brew bundle"))
    }

    @Test func `engine assesses housekeeping and identifies orphan leaf candidates`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let packages: [InstalledBrewPackage] = [
            .fixture(name: "libpng", installedVersions: ["1.6.40"], installedOnRequest: false),
            .fixture(name: "git", installedVersions: ["2.45.0"], installedOnRequest: true),
        ]

        let report = await engine.assessHousekeeping(installedPackages: packages, leaves: ["libpng", "git"])

        #expect(report.orphanCandidates.count == 2)
        let libpngCandidate = report.orphanCandidates.first(where: { $0.packageName == "libpng" })
        #expect(libpngCandidate?.safetyLevel == .safeToPrune)
        #expect(!report.recommendedCommands.isEmpty)
    }

    @Test func `engine suggests modern alternatives for legacy unix utilities`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let grepPackage = BrewPackage.fixture(name: "grep", displayName: "grep")
        let alternatives = await engine.suggestAlternatives(for: grepPackage)

        #expect(!alternatives.isEmpty)
        #expect(alternatives.contains(where: { $0.name == "ripgrep" }))
        let ripgrepAlt = alternatives.first(where: { $0.name == "ripgrep" })
        #expect(ripgrepAlt?.installCommand == "brew install ripgrep")
        #expect(ripgrepAlt?.keyAdvantages.count ?? 0 > 1)
    }

    @Test func `engine generates personalized recommendations from installed packages`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let installed: [InstalledBrewPackage] = [
            .fixture(name: "git", installedVersions: ["2.46.0"]),
            .fixture(name: "python@3.12", installedVersions: ["3.12.5"])
        ]

        let recommendations = await engine.recommendPackages(basedOn: installed)
        #expect(!recommendations.isEmpty)
        #expect(recommendations.contains(where: { $0.packageName == "lazygit" || $0.packageName == "gh" }))
        #expect(recommendations.contains(where: { $0.packageName == "uv" }))
    }

    @Test func `engine produces side by side package comparison`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let packageA = BrewPackage.fixture(name: "grep", displayName: "grep")
        let packageB = BrewPackage.fixture(name: "ripgrep", displayName: "ripgrep")

        let comparison = await engine.comparePackages(packageA: packageA, packageB: packageB)
        #expect(comparison.packageAName == "grep")
        #expect(comparison.packageBName == "ripgrep")
        #expect(comparison.verdictSummary.contains("ripgrep"))
        #expect(!comparison.strengthsA.isEmpty)
        #expect(!comparison.strengthsB.isEmpty)
        #expect(!comparison.matrix.isEmpty)
    }
}
