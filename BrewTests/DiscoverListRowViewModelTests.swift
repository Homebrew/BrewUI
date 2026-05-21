@testable import Brew
import Testing

struct DiscoverListRowViewModelTests {
    @Test @MainActor func `labels reflect empty catalogue metadata without version placeholder`() {
        let viewModel = DiscoverListRowViewModel(
            discoveryPackage: DiscoveryBrewPackage(
                package: .fixture(description: "", latestVersion: ""),
                thirtyDayInstallCount: 12345,
            ),
            installedPackage: nil,
        )

        #expect(viewModel.descriptionText.isEmpty)
        #expect(!viewModel.hasDescription)
        #expect(viewModel.stableVersionLabel.isEmpty)
        #expect(viewModel.installs30DayLabel == "12,345")
        #expect(viewModel.installedStatusLabel == nil)
        #expect(viewModel.installedVersionLabel == nil)
    }

    @Test @MainActor func `labels expose installed version when inventory has a match`() {
        let viewModel = DiscoverListRowViewModel(
            discoveryPackage: DiscoveryBrewPackage(
                package: .fixture(name: "git", latestVersion: "2.46.1"),
                thirtyDayInstallCount: 100,
            ),
            installedPackage: .fixture(name: "git", installedVersions: ["2.45.0"]),
        )

        #expect(viewModel.isInstalled)
        #expect(viewModel.installedStatusLabel == "Installed")
        #expect(viewModel.installedVersionLabel == "v2.45.0")
    }

    @Test @MainActor func `update replaces derived row values`() {
        let viewModel = DiscoverListRowViewModel(
            discoveryPackage: DiscoveryBrewPackage(
                package: .fixture(name: "wget", kind: .formula),
                thirtyDayInstallCount: 10,
            ),
            installedPackage: nil,
        )
        viewModel.update(
            discoveryPackage: DiscoveryBrewPackage(
                package: .fixture(
                    name: "iterm2",
                    kind: .cask,
                    description: "Terminal emulator",
                    latestVersion: "3.5.0",
                ),
                thirtyDayInstallCount: 99,
            ),
            installedPackage: .fixture(name: "iterm2", kind: .cask, installedVersions: ["3.4.0"]),
        )

        #expect(viewModel.id == "cask:iterm2")
        #expect(viewModel.name == "iterm2")
        #expect(viewModel.packageKind == .cask)
        #expect(viewModel.hasDescription)
        #expect(viewModel.stableVersionLabel == "3.5.0")
        #expect(viewModel.installs30DayLabel == "99")
        #expect(viewModel.installedVersionLabel == "v3.4.0")
    }
}
