//
//  DiscoveryBrewPackage+Placeholdable.swift
//  Brew
//

import Foundation

nonisolated extension DiscoveryBrewPackage: Placeholdable {
    static var placeholder: DiscoveryBrewPackage {
        DiscoveryBrewPackage(
            package: BrewPackage(
                name: "placeholder-package",
                displayName: "Placeholder Package",
                kind: .formula,
                description: "Placeholder description text for the redacted loading row.",
                homepage: "",
                latestVersion: "0.0.0",
                dependencies: [],
            ),
            thirtyDayInstallCount: 420_000,
        )
    }
}

nonisolated extension [DiscoveryBrewPackage]: Placeholdable {
    /// A spread of distinct, mixed-kind stub packages. Distinct ids keep `ForEach` happy, and the
    /// formula/cask mix lets both sections render redacted under the "All" scope while loading.
    static var placeholder: [DiscoveryBrewPackage] {
        (0 ..< 8).map { index in
            let kind: HomebrewPackageKind = index.isMultiple(of: 2) ? .formula : .cask
            return DiscoveryBrewPackage(
                package: BrewPackage(
                    name: "placeholder-\(index)",
                    displayName: "Placeholder Package \(index)",
                    kind: kind,
                    description: "Placeholder description text for the redacted loading row.",
                    homepage: "",
                    latestVersion: "0.0.0",
                    dependencies: [],
                ),
                thirtyDayInstallCount: 420_000,
            )
        }
    }
}
