//
//  AIEngineTests.swift
//  BrewRepositoriesTests
//

import BrewCore
import BrewRepositories
import BrewRepositoryInterfaces
import Foundation
import Testing

@Suite("AIEngine")
struct AIEngineTests {
    @Observable
    // Safe in test harness as instances are confined to individual test methods.
    // swiftlint:disable:next unchecked_sendable
    fileprivate final class MockModelManager: AIModelManaging, @unchecked Sendable {
        let availableModels: [AIModelSpec] = AIModelCatalog.allModels
        var activeModelID: String? = AIModelCatalog.qwenCoder15B.id
        var hardwareProfile = AISystemHardwareProfile()
        var lastErrorMessage: String?

        func downloadState(for _: AIModelSpec) -> AIModelDownloadState {
            .ready
        }

        func setActiveModel(id: String?) {
            activeModelID = id
        }

        func startDownload(for _: AIModelSpec) async {}
        func cancelDownload(for _: AIModelSpec) {}
        func deleteModel(for _: AIModelSpec) {}
    }

    @Test func `engine identifies unlinked keg and generates link command`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let result = await engine.analyzeDoctorIssue(
            title: "You have unlinked kegs in your Cellar",
            rawOutput: "node\ngit",
        )

        #expect(result.summary.contains("symlinked"))
        #expect(result.suggestedCommands.contains { $0.contains("brew link") })
    }

    @Test func `engine identifies missing command line tools and suggests xcode-select`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let result = await engine.analyzeDoctorIssue(
            title: "Your Command Line Tools (CLT) does not appear to be installed",
            rawOutput: "A CLT error was detected",
        )

        #expect(result.suggestedCommands.contains("xcode-select --install"))
    }

    @Test func `engine explains checksum mismatch error`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let result = await engine.analyzeCommandFailure(
            command: "brew install ripgrep",
            exitCode: 1,
            output: "Error: SHA256 mismatch\nExpected: abc\nActual: def",
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
            dependents: ["yarn", "pnpm"],
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
            .fixture(name: "python@3.12", installedVersions: ["3.12.5"]),
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

    @Test func `engine suggests alternatives across classic tools and GUI casks`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())

        let catAlts = await engine.suggestAlternatives(for: .fixture(name: "cat"))
        #expect(catAlts.contains(where: { $0.name == "bat" }))

        let findAlts = await engine.suggestAlternatives(for: .fixture(name: "find"))
        #expect(findAlts.contains(where: { $0.name == "fd" }))

        let lsAlts = await engine.suggestAlternatives(for: .fixture(name: "ls"))
        #expect(lsAlts.contains(where: { $0.name == "eza" }))

        let topAlts = await engine.suggestAlternatives(for: .fixture(name: "top"))
        #expect(topAlts.contains(where: { $0.name == "btop" }))

        let curlAlts = await engine.suggestAlternatives(for: .fixture(name: "curl"))
        #expect(curlAlts.contains(where: { $0.name == "httpie" }))

        let dockerAlts = await engine.suggestAlternatives(for: .fixture(name: "docker"))
        #expect(dockerAlts.contains(where: { $0.name == "orbstack" && !$0.isFormula }))

        let itermAlts = await engine.suggestAlternatives(for: .fixture(name: "iterm2"))
        #expect(itermAlts.contains(where: { $0.name == "ghostty" }))

        let unknownAlts = await engine.suggestAlternatives(for: .fixture(name: "unknown-binary-xyz"))
        #expect(unknownAlts.isEmpty)
    }

    @Test func `engine deduplicates recommendations for tools already installed`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let installed: [InstalledBrewPackage] = [
            .fixture(name: "git", installedVersions: ["2.46.0"]),
            .fixture(name: "lazygit", installedVersions: ["0.44.0"]),
            .fixture(name: "gh", installedVersions: ["2.56.0"]),
            .fixture(name: "python@3.12", installedVersions: ["3.12.5"]),
            .fixture(name: "uv", installedVersions: ["0.4.0"]),
            .fixture(name: "ripgrep", installedVersions: ["14.1.0"]),
            .fixture(name: "bat", installedVersions: ["0.24.0"]),
            .fixture(name: "eza", installedVersions: ["0.19.0"]),
            .fixture(name: "zoxide", installedVersions: ["0.9.0"]),
            .fixture(name: "raycast", installedVersions: ["1.80.0"]),
        ]

        let recommendations = await engine.recommendPackages(basedOn: installed)
        // Should not recommend tools that are already installed!
        #expect(!recommendations.contains(where: { $0.packageName == "lazygit" }))
        #expect(!recommendations.contains(where: { $0.packageName == "gh" }))
        #expect(!recommendations.contains(where: { $0.packageName == "uv" }))
        #expect(!recommendations.contains(where: { $0.packageName == "ripgrep" }))
        #expect(!recommendations.contains(where: { $0.packageName == "raycast" }))
    }

    @Test func `engine compares two general packages side by side`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let packageA = BrewPackage.fixture(name: "ghostty", displayName: "Ghostty", kind: .cask)
        let packageB = BrewPackage.fixture(name: "alacritty", displayName: "Alacritty", kind: .cask)

        let comparison = await engine.comparePackages(packageA: packageA, packageB: packageB)
        #expect(comparison.packageAName == "Ghostty")
        #expect(comparison.packageBName == "Alacritty")
        #expect(!comparison.verdictSummary.isEmpty)
        #expect(!comparison.strengthsA.isEmpty)
        #expect(!comparison.strengthsB.isEmpty)
        #expect(comparison.matrix.count == 4)
    }

    @Test func `engine handles doctor broken symlinks and generic fallback`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let brokenSymlinksResult = await engine.analyzeDoctorIssue(
            title: "You have broken symlinks in your Homebrew prefix",
            rawOutput: "/opt/homebrew/bin/dead-link",
        )
        #expect(brokenSymlinksResult.suggestedCommands.contains("brew cleanup -s"))

        let genericResult = await engine.analyzeDoctorIssue(
            title: "Something unexpected occurred",
            rawOutput: "random debug details",
        )
        #expect(genericResult.suggestedCommands.contains("brew doctor"))
    }

    @Test func `engine handles command permission error and bottle missing`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let permResult = await engine.analyzeCommandFailure(
            command: "brew install node",
            exitCode: 1,
            output: "Permission denied @ dir_s_mkdir - /usr/local/share/man",
        )
        #expect(permResult.summary.contains("permissions") || permResult.summary.contains("Permission"))

        let bottleResult = await engine.analyzeCommandFailure(
            command: "brew install special-tool",
            exitCode: 1,
            output: "Error: No bottle available!",
        )
        #expect(bottleResult.suggestedCommands.contains { $0.contains("--build-from-source") })
    }

    @Test @MainActor func `model manager manages active model and download state`() {
        let defaultsSuite = "test.brew.modelmanager.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsSuite) else { return }
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = BrewAIModelManager(modelsDirectory: tempDir, defaults: defaults)
        #expect(!manager.availableModels.isEmpty)

        let firstModel = manager.availableModels[0]
        #expect(manager.downloadState(for: firstModel) == .notDownloaded)

        manager.setActiveModel(id: firstModel.id)
        #expect(manager.activeModelID == firstModel.id)

        manager.setActiveModel(id: nil as String?)
        #expect(manager.activeModelID == nil)
    }

    @Test @MainActor func `model manager deleteModel cancels download and removes file`() {
        let defaultsSuite = "test.brew.modelmanager.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsSuite) else { return }
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = BrewAIModelManager(modelsDirectory: tempDir, defaults: defaults)
        let model = manager.availableModels[0]

        // Manually place a fake model file in tempDir
        let fileURL = tempDir.appendingPathComponent(model.filename)
        try? "marker".write(to: fileURL, atomically: true, encoding: .utf8)
        #expect(manager.downloadState(for: model) == .ready)

        manager.setActiveModel(id: model.id)
        manager.deleteModel(for: model)

        #expect(manager.downloadState(for: model) == .notDownloaded)
        #expect(manager.activeModelID == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func `engine extracts formula names across blank lines in doctor output`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let doctorText = """
        Warning: You have unlinked kegs in your Cellar.
        Leaving kegs unlinked can lead to build-trouble. Run `brew link` on these:

          `openssl@3`
          readline

        Homebrew doctor finished.
        """
        let result = await engine.analyzeDoctorIssue(
            title: "You have unlinked kegs in your Cellar",
            rawOutput: doctorText,
        )

        #expect(result.suggestedCommands.contains("brew link --overwrite openssl@3"))
        #expect(result.suggestedCommands.contains("brew link --overwrite readline"))
    }

    @Test func `engine detects major version bumps with v prefix and versioned daemons`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let package = InstalledBrewPackage.fixture(
            name: "postgresql@16",
            latestVersion: "v17.0.0",
            installedVersions: ["v16.4.0"],
        )

        let impact = await engine.assessUpgradeImpact(
            package: package,
            targetVersion: "v17.0.0",
            dependents: ["app-backend"],
        )

        #expect(impact.isMajorVersionBump)
        #expect(impact.riskLevel == .high)
        #expect(impact.serviceRestartNotice != nil)
        #expect(impact.recommendedVerificationCommands.contains("brew services restart postgresql@16"))
    }

    @Test func `engine handles non-major version bump with low risk`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let package = InstalledBrewPackage.fixture(
            name: "curl",
            latestVersion: "v8.10.1",
            installedVersions: ["v8.10.0"],
        )

        let impact = await engine.assessUpgradeImpact(
            package: package,
            targetVersion: "v8.10.1",
            dependents: [],
        )

        #expect(!impact.isMajorVersionBump)
        #expect(impact.riskLevel == .low)
    }

    @Test func `engine extracts package name ignoring flags on command failure`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let failure = await engine.analyzeCommandFailure(
            command: "brew install ripgrep --verbose --debug",
            exitCode: 1,
            output: "Error: SHA256 mismatch",
        )

        #expect(failure.suggestedCommands.contains("brew fetch --force ripgrep"))
    }

    @Test func `engine handles command failure with no package argument safely`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let failure = await engine.analyzeCommandFailure(
            command: "brew install",
            exitCode: 1,
            output: "Error: already installed",
        )

        #expect(failure.suggestedCommands.contains("brew doctor"))
    }

    @Test func `hardware profile with zero memory defaults to heavy without crashing`() {
        let zeroProfile = AISystemHardwareProfile(totalMemoryBytes: 0)
        let spec = AIModelCatalog.smolLM2
        #expect(zeroProfile.fit(for: spec) == .heavy)
    }

    @Test func `devops brewfile generation avoids docker formula and cask collision`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let env = await engine.generateBrewfileEnvironment(prompt: "Devops Docker and cloud stack")

        #expect(env.casks.contains("docker"))
        #expect(!env.formulae.contains("docker"))
    }

    @Test func `engine comparison formats unknown versions cleanly`() async {
        let engine = LocalAIEngine(modelManager: MockModelManager())
        let packageA = BrewPackage.fixture(name: "pkg-a", latestVersion: "")
        let packageB = BrewPackage.fixture(name: "pkg-b", latestVersion: "1.2.3")

        let comparison = await engine.comparePackages(packageA: packageA, packageB: packageB)
        let versionRow = comparison.matrix.first(where: { $0.feature == "Latest Version" })
        #expect(versionRow?.packageAValue == "Unknown")
        #expect(versionRow?.packageBValue == "1.2.3")
    }
}
