@testable import Brew

extension BrewPackage {
    static func fixture(
        name: String = "git",
        kind: HomebrewPackageKind = .formula,
        description: String = "",
        homepage: String = "",
        latestVersion: String = "",
        installedVersions: [String] = [],
        dependencies: [HomebrewPackageReference] = [],
        outdated: Bool = false,
    ) -> BrewPackage {
        BrewPackage(
            name: name,
            kind: kind,
            description: description,
            homepage: homepage,
            latestVersion: latestVersion,
            installedVersions: installedVersions,
            dependencies: dependencies,
            outdated: outdated,
        )
    }
}

extension [BrewPackage] {
    static var empty: [BrewPackage] {
        []
    }
}
