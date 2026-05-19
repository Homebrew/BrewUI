@testable import Brew

extension BrewPackage {
    static func fixture(
        name: String = "git",
        displayName: String? = nil,
        kind: HomebrewPackageKind = .formula,
        description: String = "",
        homepage: String = "",
        latestVersion: String = "",
        dependencies: [HomebrewPackageReference] = [],
    ) -> BrewPackage {
        BrewPackage(
            name: name,
            displayName: displayName ?? name,
            kind: kind,
            description: description,
            homepage: homepage,
            latestVersion: latestVersion,
            dependencies: dependencies,
        )
    }
}

extension [BrewPackage] {
    static var empty: [BrewPackage] {
        []
    }
}

extension InstalledBrewPackage {
    static func fixture(
        name: String = "git",
        displayName: String? = nil,
        kind: HomebrewPackageKind = .formula,
        description: String = "",
        homepage: String = "",
        latestVersion: String = "",
        installedVersions: [String] = [],
        dependencies: [HomebrewPackageReference] = [],
        outdated: Bool = false,
    ) -> InstalledBrewPackage {
        InstalledBrewPackage(
            package: .fixture(
                name: name,
                displayName: displayName,
                kind: kind,
                description: description,
                homepage: homepage,
                latestVersion: latestVersion,
                dependencies: dependencies,
            ),
            installedVersions: installedVersions,
            outdated: outdated,
        )
    }
}

extension [InstalledBrewPackage] {
    static var empty: [InstalledBrewPackage] {
        []
    }
}
