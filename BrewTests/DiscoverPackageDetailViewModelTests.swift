@testable import Brew
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
        )

        #expect(viewModel.packageKind == .formula)
        #expect(viewModel.installCommand == "brew install wget")
        #expect(viewModel.installedStatusLabel == "Installed")
        #expect(viewModel.installedVersionLabel == "v1.9.0")
        #expect(viewModel.stableVersionLabel == "2.0.0")
        #expect(viewModel.installs30DayLabel == "3,500")
        #expect(viewModel.showsInstallMetrics)
        #expect(viewModel.homepageURL?.absoluteString == "https://example.org")
    }

    @Test @MainActor func `cask package maps cask install command and not installed status`() {
        let viewModel = DiscoverPackageDetailViewModel(
            package: DiscoveryBrewPackage(
                package: .fixture(name: "iterm2", kind: .cask, homepage: "", latestVersion: ""),
                thirtyDayInstallCount: 500,
            ),
            installedRepository: installedRepo(),
            brewCommandCenter: NoopBrewCommandCenter.forTesting(),
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
}

@MainActor
private func installedRepo(_ packages: [InstalledBrewPackage] = []) -> BrewInstalledPackagesRepository {
    BrewInstalledPackagesRepository.previewLoaded(packages)
}
