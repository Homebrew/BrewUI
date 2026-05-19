@testable import Brew
import Foundation
import Testing

struct DiscoverPackageDetailViewModelTests {
    @Test @MainActor func `formula row maps install command and installed status`() {
        let row = DiscoverListRowViewModel(
            package: .fixture(
                name: "wget",
                homepage: "https://example.org",
                latestVersion: "2.0.0",
            ),
            analyticsInstallCount: 3500,
            installedPackage: .fixture(name: "wget", installedVersions: ["1.9.0"]),
        )
        let viewModel = DiscoverPackageDetailViewModel(row: row)

        #expect(viewModel.packageKind == .formula)
        #expect(viewModel.installCommand == "brew install wget")
        #expect(viewModel.installedStatusText == "Installed")
        #expect(viewModel.installedVersionLabel == "v1.9.0")
        #expect(viewModel.stableVersionLabel == "2.0.0")
        #expect(viewModel.installs30DayLabel == "3,500")
        #expect(viewModel.homepageURL?.absoluteString == "https://example.org")
    }

    @Test @MainActor func `cask row maps cask install command and not installed status`() {
        let row = DiscoverListRowViewModel(
            package: .fixture(name: "iterm2", kind: .cask, homepage: "", latestVersion: ""),
            analyticsInstallCount: 500,
            installedPackage: nil,
        )
        let viewModel = DiscoverPackageDetailViewModel(row: row)

        #expect(viewModel.packageKind == .cask)
        #expect(viewModel.installCommand == "brew install --cask iterm2")
        #expect(viewModel.installedStatusText == "Not installed")
        #expect(viewModel.installedVersionLabel == nil)
        #expect(viewModel.stableVersionLabel == "—")
        #expect(viewModel.installs30DayLabel == "500")
        #expect(viewModel.homepageURL == nil)
    }

    @Test @MainActor func `update refreshes derived detail presentation`() {
        let row = DiscoverListRowViewModel(
            package: .fixture(name: "wget"),
            analyticsInstallCount: 1,
            installedPackage: .fixture(name: "wget", installedVersions: ["1.0.0"]),
        )
        let viewModel = DiscoverPackageDetailViewModel(row: row)
        viewModel.update(
            row: DiscoverListRowViewModel(
                package: .fixture(name: "docker", kind: .cask, homepage: "https://docker.com", latestVersion: "4.0.0"),
                analyticsInstallCount: 42,
                installedPackage: nil,
            ),
        )

        #expect(viewModel.name == "docker")
        #expect(viewModel.packageKind == .cask)
        #expect(viewModel.installCommand == "brew install --cask docker")
        #expect(viewModel.installedStatusText == "Not installed")
        #expect(viewModel.installedVersionLabel == nil)
        #expect(viewModel.stableVersionLabel == "4.0.0")
        #expect(viewModel.homepageURL?.absoluteString == "https://docker.com")
    }
}
