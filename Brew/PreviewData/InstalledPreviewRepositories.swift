import Foundation

enum InstalledPreviewData {
    static let snapshot = InstalledPackagesSnapshot(
        formulae: [
            InstalledPackageInfo(name: "git", version: "2.45.0"),
            InstalledPackageInfo(name: "node", version: "22.14.0"),
            InstalledPackageInfo(name: "python", version: "3.13.2"),
        ],
        casks: [
            InstalledPackageInfo(name: "visual-studio-code", version: "1.99.0"),
            InstalledPackageInfo(name: "docker", version: "4.39.0"),
        ],
    )

    static func details(for name: String, preferredKind: InstalledPackageKind?) -> InstalledPackageDetails {
        switch (name, preferredKind) {
        case ("docker", .cask):
            InstalledPackageDetails(
                name: "docker",
                kind: .cask,
                description: "App to build and share containerized applications",
                version: "4.39.0",
                installedVersions: ["4.39.0"],
                homepage: "https://www.docker.com",
                dependencies: [],
                outdated: false,
                availableVersion: nil,
            )
        case ("visual-studio-code", .cask):
            InstalledPackageDetails(
                name: "visual-studio-code",
                kind: .cask,
                description: "Code editing redefined",
                version: "1.99.0",
                installedVersions: ["1.99.0"],
                homepage: "https://code.visualstudio.com",
                dependencies: [],
                outdated: false,
                availableVersion: nil,
            )
        default:
            InstalledPackageDetails(
                name: "git",
                kind: .formula,
                description: "Distributed revision control system",
                version: "2.45.0",
                installedVersions: ["2.45.0"],
                homepage: "https://git-scm.com",
                dependencies: ["gettext", "pcre2"],
                outdated: true,
                availableVersion: "2.46.1",
            )
        }
    }
}

struct PreviewInstalledPackagesRepository: InstalledPackagesRepository {
    func loadInstalledPackages() async throws -> InstalledPackagesSnapshot {
        InstalledPreviewData.snapshot
    }
}

struct PreviewPackageDetailsRepository: PackageDetailsRepository {
    func loadPackageDetails(
        named name: String,
        preferredKind: InstalledPackageKind?,
    ) async throws -> InstalledPackageDetails {
        InstalledPreviewData.details(for: name, preferredKind: preferredKind)
    }
}
