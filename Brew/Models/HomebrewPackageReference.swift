//
//  HomebrewPackageReference.swift
//  Brew
//

import Foundation

/// Kind-qualified reference to a Homebrew formula name or cask token.
///
/// This is the canonical package identity across the app: every package type's
/// `id` is a `HomebrewPackageID`, and the type is its own `Identifiable.ID`.
enum HomebrewPackageID: Hashable, Identifiable {
    case formula(name: String)
    case cask(token: String)

    var id: Self {
        self
    }

    var kind: HomebrewPackageKind {
        switch self {
        case .formula:
            .formula
        case .cask:
            .cask
        }
    }

    var name: String {
        switch self {
        case let .formula(name):
            name
        case let .cask(token):
            token
        }
    }

    init(package: BrewPackage) {
        switch package.kind {
        case .formula:
            self = .formula(name: package.name)
        case .cask:
            self = .cask(token: package.name)
        }
    }

    init(installedPackage: InstalledBrewPackage) {
        self.init(package: installedPackage.package)
    }
}

extension HomebrewPackageID {
    static func formulaDependencies(from names: [String]) -> [HomebrewPackageID] {
        uniqueReferences(names.map { .formula(name: $0) })
    }

    static func uniqueReferences(_ references: [HomebrewPackageID]) -> [HomebrewPackageID] {
        var seen: Set<HomebrewPackageID> = []
        var result: [HomebrewPackageID] = []
        for reference in references {
            guard let normalized = reference.normalized, !seen.contains(normalized) else {
                continue
            }
            seen.insert(normalized)
            result.append(normalized)
        }
        return result
    }

    private var normalized: HomebrewPackageID? {
        switch self {
        case let .formula(name):
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }
            return .formula(name: trimmed)
        case let .cask(token):
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }
            return .cask(token: trimmed)
        }
    }
}
