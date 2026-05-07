import Foundation

enum InstalledPreviewData {
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

    static func details(for name: String, preferredKind: InstalledPackageKind?) -> BrewPackage {
        switch (name, preferredKind) {
        case ("docker", .cask):
            BrewPackage(
                name: "docker",
                kind: .cask,
                description: "App to build and share containerized applications",
                homepage: "https://www.docker.com",
                latestVersion: "4.39.0",
                installedVersions: ["4.39.0"],
                dependencies: [],
                outdated: false,
            )
        case ("visual-studio-code", .cask):
            BrewPackage(
                name: "visual-studio-code",
                kind: .cask,
                description: "Code editing redefined",
                homepage: "https://code.visualstudio.com",
                latestVersion: "1.99.0",
                installedVersions: ["1.99.0"],
                dependencies: [],
                outdated: false,
            )
        default:
            BrewPackage(
                name: "git",
                kind: .formula,
                description: "Distributed revision control system",
                homepage: "https://git-scm.com",
                latestVersion: "2.46.1",
                installedVersions: ["2.45.0"],
                dependencies: ["gettext", "pcre2"],
                outdated: true,
            )
        }
    }
}

struct PreviewInstalledPackagesRepository: InstalledPackagesRepository {
    func loadInstalledPackages() async throws -> [BrewPackage] {
        InstalledPreviewData.snapshot
    }
}

struct PreviewPackageDetailsRepository: PackageDetailsRepository {
    func loadPackageDetails(
        named name: String,
        preferredKind: InstalledPackageKind?,
    ) async throws -> BrewPackage {
        InstalledPreviewData.details(for: name, preferredKind: preferredKind)
    }
}
