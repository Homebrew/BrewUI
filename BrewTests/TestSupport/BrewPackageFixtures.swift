@testable import Brew

extension BrewPackage {
    static func fixture(
        name: String = "git",
        kind: HomebrewPackageKind = .formula,
        description: String? = nil,
        homepage: String? = nil,
        latestVersion: String? = nil,
        installedVersions: [String] = [],
        dependencies: [String] = [],
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
