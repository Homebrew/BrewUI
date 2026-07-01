//
//  InstalledBrewPackage.swift
//  BrewCore
//

import Foundation

public struct InstalledBrewPackage: Identifiable, Hashable, Sendable {
    public var package: BrewPackage
    public var installedVersions: [String]
    public var outdated: Bool
    /// SPDX license identifier, if known (formula only).
    public var license: String?
    /// Source tap, e.g. `"homebrew/core"`.
    public var tap: String?
    /// True when installed directly by the user; false when installed as a dependency.
    public var installedOnRequest: Bool
    /// True when the keg was poured from a bottle rather than built from source.
    public var pouredFromBottle: Bool
    /// When the package was installed (from the first installed entry's `time` field).
    public var installDate: Date?
    /// Version string of the currently-linked keg; nil if unlinked.
    public var linkedKeg: String?
    /// True when the package is pinned (brew pin).
    public var pinned: Bool
    /// True when the formula is keg-only (not linked into the prefix by default).
    public var kegOnly: Bool
    /// Post-install caveats text, if any.
    public var caveats: String?

    public var name: String {
        package.name
    }

    public var displayName: String {
        package.displayName
    }

    public var kind: HomebrewPackageKind {
        package.kind
    }

    public var description: String {
        get { package.description }
        set { package.description = newValue }
    }

    public var homepage: String {
        get { package.homepage }
        set { package.homepage = newValue }
    }

    public var latestVersion: String {
        get { package.latestVersion }
        set { package.latestVersion = newValue }
    }

    public var dependencies: [HomebrewPackageID] {
        get { package.dependencies }
        set { package.dependencies = newValue }
    }

    public var id: HomebrewPackageID {
        package.id
    }

    public var reference: HomebrewPackageID {
        HomebrewPackageID(package: package)
    }

    /// Direct link to the formula's source file on GitHub; only available for homebrew/core formulae.
    public var formulaSourceURL: URL? {
        guard kind == .formula, tap == "homebrew/core" else { return nil }
        let firstLetter = String(name.prefix(1)).lowercased()
        return URL(string: "https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/\(firstLetter)/\(name).rb")
    }

    public init(
        package: BrewPackage,
        installedVersions: [String],
        outdated: Bool,
        license: String? = nil,
        tap: String? = nil,
        installedOnRequest: Bool = true,
        pouredFromBottle: Bool = false,
        installDate: Date? = nil,
        linkedKeg: String? = nil,
        pinned: Bool = false,
        kegOnly: Bool = false,
        caveats: String? = nil,
    ) {
        self.package = package
        self.installedVersions = installedVersions
        self.outdated = outdated
        self.license = license
        self.tap = tap
        self.installedOnRequest = installedOnRequest
        self.pouredFromBottle = pouredFromBottle
        self.installDate = installDate
        self.linkedKeg = linkedKeg
        self.pinned = pinned
        self.kegOnly = kegOnly
        self.caveats = caveats
    }
}
