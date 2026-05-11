import Foundation

private enum InstalledPreviewData {
    static let snapshot: [BrewPackage] = [
        BrewPackage(
            name: "git",
            kind: .formula,
            description: "",
            homepage: "",
            latestVersion: "2.46.1",
            installedVersions: ["2.45.0"],
            dependencies: [],
            outdated: true,
        ),
        BrewPackage(
            name: "node",
            kind: .formula,
            description: "",
            homepage: "",
            latestVersion: "22.14.0",
            installedVersions: ["22.14.0"],
            dependencies: [],
            outdated: false,
        ),
        BrewPackage(
            name: "python",
            kind: .formula,
            description: "",
            homepage: "",
            latestVersion: "3.13.2",
            installedVersions: ["3.13.2"],
            dependencies: [],
            outdated: false,
        ),
        BrewPackage(
            name: "visual-studio-code",
            kind: .cask,
            description: "",
            homepage: "",
            latestVersion: "1.99.0",
            installedVersions: ["1.99.0"],
            dependencies: [],
            outdated: false,
        ),
        BrewPackage(
            name: "docker",
            kind: .cask,
            description: "",
            homepage: "",
            latestVersion: "4.39.0",
            installedVersions: ["4.39.0"],
            dependencies: [],
            outdated: false,
        ),
    ]
}

struct PreviewInstalledPackagesRepository: InstalledPackagesRepository {
    func loadInstalledPackages() async throws -> [BrewPackage] {
        InstalledPreviewData.snapshot
    }
}
