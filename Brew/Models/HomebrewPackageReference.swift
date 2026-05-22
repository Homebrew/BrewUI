//
//  HomebrewPackageReference.swift
//  Brew
//

import Foundation

/// Kind-qualified reference to a Homebrew formula name or cask token.
enum HomebrewPackageReference: Hashable {
    case formula(name: String)
    case cask(token: String)

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

    var packageID: BrewPackage.ID {
        switch self {
        case let .formula(name):
            "\(HomebrewPackageKind.formula.rawValue):\(name)"
        case let .cask(token):
            "\(HomebrewPackageKind.cask.rawValue):\(token)"
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

extension HomebrewPackageReference {
    static func formulaDependencies(from names: [String]) -> [HomebrewPackageReference] {
        uniqueReferences(names.map { .formula(name: $0) })
    }

    static func uniqueReferences(_ references: [HomebrewPackageReference]) -> [HomebrewPackageReference] {
        var seen: Set<HomebrewPackageReference> = []
        var result: [HomebrewPackageReference] = []
        for reference in references {
            guard let normalized = reference.normalized, !seen.contains(normalized) else {
                continue
            }
            seen.insert(normalized)
            result.append(normalized)
        }
        return result
    }

    private var normalized: HomebrewPackageReference? {
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
