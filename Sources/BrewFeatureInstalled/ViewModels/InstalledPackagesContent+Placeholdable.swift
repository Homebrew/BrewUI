//
//  InstalledPackagesContent+Placeholdable.swift
//  BrewFeatureInstalled
//

import BrewCore

extension InstalledPackagesContent: Placeholdable {
    /// A small mixed-kind stub so the redacted skeleton renders a plausible interleaved list of
    /// formula and cask rows. Distinct ids keep `ForEach` happy under `.redacted`.
    static var placeholder: InstalledPackagesContent {
        let formulae = (0 ..< 3).map { index in
            InstalledBrewPackage(
                package: BrewPackage(
                    name: "placeholder-formula-\(index)",
                    displayName: "Placeholder Formula \(index)",
                    kind: .formula,
                    description: "Placeholder description text for the redacted loading row.",
                    homepage: "",
                    latestVersion: "0.0.0",
                    dependencies: [],
                ),
                installedVersions: ["0.0.0"],
                outdated: false,
            )
        }
        let cask = InstalledBrewPackage(
            package: BrewPackage(
                name: "placeholder-cask",
                displayName: "Placeholder Cask",
                kind: .cask,
                description: "Placeholder description text for the redacted loading row.",
                homepage: "",
                latestVersion: "0.0.0",
                dependencies: [],
            ),
            installedVersions: ["0.0.0"],
            outdated: false,
        )
        return InstalledPackagesContent(packages: formulae + [cask])
    }
}
