import BrewCLI
import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureDiscover
import BrewRepositoryInterfaces
import Foundation
import Testing

struct DiscoverPackageDetailViewModelTests {
    @Test @MainActor func `formula package maps install command and installed status`() {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(
                package: .fixture(
                    name: "wget",
                    homepage: "https://example.org",
                    latestVersion: "2.0.0",
                ),
                thirtyDayInstallCount: 3500,
            ),
            installedRepository: installedRepo([.fixture(name: "wget", installedVersions: ["1.9.0"])]),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(viewModel.packageKind == .formula)
        #expect(viewModel.installCommand == "brew install wget")
        #expect(viewModel.installedStatusLabel == "Installed")
        #expect(viewModel.installedVersionLabel == "v1.9.0")
        #expect(viewModel.stableVersionLabel == "2.0.0")
        #expect(viewModel.installs30DayLabel == 3500.formatted())
        #expect(viewModel.showsInstallMetrics)
        #expect(viewModel.homepageURL?.absoluteString == "https://example.org")
    }

    @Test @MainActor func `linked annotation is suppressed for single installed version`() {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(package: .fixture(name: "wget"), thirtyDayInstallCount: 1),
            installedRepository: installedRepo([
                .fixture(name: "wget", installedVersions: ["1.9.0"], linkedKeg: "1.9.0"),
            ]),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(viewModel.installedVersionLabel == "v1.9.0")
    }

    @Test @MainActor func `linked annotation appears for linked keg when multiple versions are installed`() {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(package: .fixture(name: "wget"), thirtyDayInstallCount: 1),
            installedRepository: installedRepo([
                .fixture(name: "wget", installedVersions: ["1.9.0", "2.0.0"], linkedKeg: "2.0.0"),
            ]),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(viewModel.installedVersionLabel == "v2.0.0 (linked)")
    }

    @Test @MainActor func `cask package maps cask install command and not installed status`() {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(
                package: .fixture(name: "iterm2", kind: .cask, homepage: "", latestVersion: ""),
                thirtyDayInstallCount: 500,
            ),
            installedRepository: installedRepo(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(viewModel.packageKind == .cask)
        #expect(viewModel.installCommand == "brew install --cask iterm2")
        #expect(viewModel.installedStatusLabel == nil)
        #expect(viewModel.installedVersionLabel == nil)
        #expect(viewModel.stableVersionLabel.isEmpty)
        #expect(viewModel.installs30DayLabel == "500")
        #expect(viewModel.homepageURL == nil)
    }

    @Test @MainActor func `showsInstallMetrics is false for zero install count`() {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(
                package: .fixture(name: "ripgrep"),
                thirtyDayInstallCount: 0,
            ),
            installedRepository: installedRepo(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(!viewModel.showsInstallMetrics)
    }

    @Test @MainActor func `packageDescription is nil when description is whitespace-only`() {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(
                package: .fixture(description: "   \n  "),
                thirtyDayInstallCount: 1,
            ),
            installedRepository: installedRepo(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(viewModel.packageDescription == nil)
    }

    @Test @MainActor func `packageDescription returns trimmed non-empty description`() {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(
                package: .fixture(description: "  A useful tool.  "),
                thirtyDayInstallCount: 1,
            ),
            installedRepository: installedRepo(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(viewModel.packageDescription == "A useful tool.")
    }

    @Test @MainActor func `dependencyNames maps formula dependency references to names`() {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(
                package: .fixture(
                    name: "ffmpeg",
                    dependencies: [.formula(name: "libx264"), .formula(name: "libvpx")],
                ),
                thirtyDayInstallCount: 1,
            ),
            installedRepository: installedRepo(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(viewModel.dependencyNames == ["libx264", "libvpx"])
    }

    @Test @MainActor func `dependencyNames is empty when package has no dependencies`() {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(
                package: .fixture(dependencies: []),
                thirtyDayInstallCount: 1,
            ),
            installedRepository: installedRepo(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(viewModel.dependencyNames.isEmpty)
    }

    @Test @MainActor func `homepageURL is nil for empty homepage string`() {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(
                package: .fixture(homepage: ""),
                thirtyDayInstallCount: 1,
            ),
            installedRepository: installedRepo(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(viewModel.homepageURL == nil)
    }

    @Test @MainActor func `homepageURL is nil for whitespace-only homepage string`() {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(
                package: .fixture(homepage: "   "),
                thirtyDayInstallCount: 1,
            ),
            installedRepository: installedRepo(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(viewModel.homepageURL == nil)
    }

    @Test @MainActor func `update refreshes derived detail presentation`() {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(
                package: .fixture(name: "wget"),
                thirtyDayInstallCount: 1,
            ),
            installedRepository: installedRepo([.fixture(name: "wget", installedVersions: ["1.0.0"])]),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        viewModel.update(
            package: DiscoveryBrewPackage(
                package: .fixture(
                    name: "docker",
                    kind: .cask,
                    homepage: "https://docker.com",
                    latestVersion: "4.0.0",
                ),
                thirtyDayInstallCount: 42,
            ),
        )

        #expect(viewModel.name == "docker")
        #expect(viewModel.packageKind == .cask)
        #expect(viewModel.installCommand == "brew install --cask docker")
        // The new package isn't in the installed repository, so installed labels go to nil.
        #expect(viewModel.installedStatusLabel == nil)
        #expect(viewModel.installedVersionLabel == nil)
        #expect(viewModel.stableVersionLabel == "4.0.0")
        #expect(viewModel.homepageURL?.absoluteString == "https://docker.com")
    }

    // MARK: - AI Alternatives and Comparison

    @Test @MainActor func `loadAlternatives populates alternatives from AI engine`() async {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(package: .fixture(name: "grep"), thirtyDayInstallCount: 0),
            installedRepository: installedRepo(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(viewModel.alternatives.isEmpty)
        await viewModel.loadAlternatives(using: PreviewSupport.aiEngine)
        #expect(!viewModel.alternatives.isEmpty)
        #expect(viewModel.alternatives.contains(where: { $0.name == "ripgrep" }))
    }

    @Test @MainActor func `compare triggers AI comparison and opens sheet`() async {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(package: .fixture(name: "grep"), thirtyDayInstallCount: 0),
            installedRepository: installedRepo(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(!viewModel.isShowingComparison)
        #expect(viewModel.comparisonResult == nil)

        let catalogue = PreviewSupport.makeDiscoverCatalogueRepository()
        await viewModel.compare(with: "ripgrep", using: PreviewSupport.aiEngine, catalogue: catalogue)

        #expect(viewModel.isShowingComparison)
        #expect(viewModel.comparisonResult != nil)
        #expect(viewModel.comparisonTarget?.name == "ripgrep")

        viewModel.dismissComparison()
        #expect(!viewModel.isShowingComparison)
    }

    @Test @MainActor func `installAlternative triggers command execution`() {
        let factory = StubMutatingCommandFactory()
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(package: .fixture(name: "grep"), thirtyDayInstallCount: 0),
            installedRepository: installedRepo(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: factory,
        )

        viewModel.installAlternative(command: "brew install ripgrep")
        #expect(viewModel.installErrorMessage == nil)
    }

    @Test @MainActor func `installPackage tracks installing state for alternative`() {
        let factory = StubMutatingCommandFactory()
        let altPackage = BrewPackage.fixture(name: "ripgrep")
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(package: .fixture(name: "grep"), thirtyDayInstallCount: 0),
            installedRepository: installedRepo(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: factory,
        )

        viewModel.installPackage(altPackage)
        #expect(viewModel.isPackageInstalling(altPackage.id))
        #expect(viewModel.isInstalling)
    }

    @Test @MainActor func `update package resets alternatives and comparison state`() async {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(package: .fixture(name: "grep"), thirtyDayInstallCount: 0),
            installedRepository: installedRepo(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
            commandFactory: StubMutatingCommandFactory(),
        )

        await viewModel.loadAlternatives(using: PreviewSupport.aiEngine)
        let catalogue = PreviewSupport.makeDiscoverCatalogueRepository()
        await viewModel.compare(with: "ripgrep", using: PreviewSupport.aiEngine, catalogue: catalogue)

        #expect(!viewModel.alternatives.isEmpty)
        #expect(viewModel.isShowingComparison)

        viewModel.update(package: DiscoveryBrewPackage(package: .fixture(name: "curl"), thirtyDayInstallCount: 0))

        #expect(viewModel.alternatives.isEmpty)
        #expect(!viewModel.isShowingComparison)
        #expect(viewModel.comparisonResult == nil)
        #expect(viewModel.comparisonTarget == nil)
    }

    @Test @MainActor func `update package resets busy state across package selection changes`() async {
        let (stream, continuation) = AsyncStream<BrewOperationPhase>.makeStream()
        let commandCenter = MockStreamingCommandCenter(stream: stream)
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(package: .fixture(name: "grep"), thirtyDayInstallCount: 0),
            installedRepository: installedRepo(),
            brewCommandCenter: commandCenter,
            commandFactory: StubMutatingCommandFactory(),
        )

        let task = Task {
            await viewModel.observeInstallUpdates()
        }
        continuation.yield(.running(.installFormula))
        for _ in 0 ..< 10 {
            await Task.yield()
        }

        #expect(viewModel.isInstalling)

        let curlPackage = DiscoveryBrewPackage(package: .fixture(name: "curl"), thirtyDayInstallCount: 0)
        viewModel.update(package: curlPackage)

        #expect(!viewModel.isInstalling)
        #expect(!viewModel.isPackageInstalling(curlPackage.id))

        continuation.finish()
        await task.value
    }
}

private actor MockStreamingCommandCenter: BrewCommandCenter {
    let stream: AsyncStream<BrewOperationPhase>

    init(stream: AsyncStream<BrewOperationPhase>) {
        self.stream = stream
    }

    func phase(for _: BrewOperationID) async -> BrewOperationPhase {
        .idle
    }

    func runningPhases() async -> [BrewOperationID: BrewOperationPhase] {
        [:]
    }

    func perform(_: BrewCommand, id _: BrewOperationID) async throws {}

    func capture(_: BrewCommand, id _: BrewOperationID) async throws -> CommandOutput {
        CommandOutput(standardOutput: "", standardError: "", terminationStatus: 0)
    }

    func phaseChanges(for _: BrewOperationID) async -> AsyncStream<BrewOperationPhase> {
        stream
    }

    func allPhaseChanges() async -> AsyncStream<(BrewOperationID, BrewOperationPhase)> {
        AsyncStream { $0.finish() }
    }

    func allOutputChanges() async -> AsyncStream<(BrewOperationID, BrewCommandOutputLine)> {
        AsyncStream { $0.finish() }
    }
}

@MainActor
private func installedRepo(_ packages: [InstalledBrewPackage] = []) -> StubInstalledPackagesRepository {
    StubInstalledPackagesRepository(packages: packages)
}
