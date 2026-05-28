//
//  BrewAnalyticsJSON.swift
//  Brew
//

import Foundation

/// Supported Homebrew analytics windows used by Discover.
nonisolated enum BrewAnalyticsWindow: String, CaseIterable {
    case days30 = "30d"
    case days90 = "90d"
    case days365 = "365d"
}

/// Strict schema for Homebrew analytics API responses.
nonisolated struct BrewAnalyticsJSON: Decodable {
    let category: String
    let totalItems: Int
    let totalCount: Int
    let startDate: String
    let endDate: String
    private let parsedPackageCounts: [BrewAnalyticsPackageCount]

    var packageCounts: [BrewAnalyticsPackageCount] {
        parsedPackageCounts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decodeNonEmptyString(forKey: .category)
        totalItems = try container.decodeRequiredIntLossy(forKey: .totalItems)
        totalCount = try container.decodeRequiredIntLossy(forKey: .totalCount)
        startDate = try container.decodeNonEmptyString(forKey: .startDate)
        endDate = try container.decodeNonEmptyString(forKey: .endDate)

        let packageBuckets: [String: [BrewAnalyticsEntry]]
        if container.contains(.formulae) {
            packageBuckets = try container.decode([String: [BrewAnalyticsEntry]].self, forKey: .formulae)
        } else if container.contains(.casks) {
            packageBuckets = try container.decode([String: [BrewAnalyticsEntry]].self, forKey: .casks)
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.formulae,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Expected formulae or casks analytics buckets.",
                ),
            )
        }

        parsedPackageCounts = try packageBuckets.map { bucketName, entries in
            let normalizedBucket = bucketName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let firstEntry = entries.first else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Analytics bucket '\(normalizedBucket)' has no entries.",
                    ),
                )
            }
            let reference = try firstEntry.requiredReference(codingPath: container.codingPath)
            return BrewAnalyticsPackageCount(reference: reference, count: firstEntry.count)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case category
        case totalItems = "total_items"
        case totalCount = "total_count"
        case startDate = "start_date"
        case endDate = "end_date"
        case formulae
        case casks
    }
}

nonisolated struct BrewAnalyticsPackageCount: Hashable {
    let reference: HomebrewPackageID
    let count: Int

    var name: String {
        reference.name
    }
}

private nonisolated struct BrewAnalyticsEntry: Decodable {
    let formula: String?
    let cask: String?
    let count: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formula = try container.decodeIfPresent(String.self, forKey: .formula)
        cask = try container.decodeIfPresent(String.self, forKey: .cask)
        count = try container.decodeRequiredIntLossy(forKey: .count)
    }

    func requiredReference(codingPath: [CodingKey]) throws -> HomebrewPackageID {
        let formulaName = Self.trimmedOrNil(formula)
        let caskToken = Self.trimmedOrNil(cask)

        switch (formulaName, caskToken) {
        case let (.some(name), nil):
            return .formula(name: name)
        case let (nil, .some(token)):
            return .cask(token: token)
        case (.none, .none):
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Analytics entry must include formula or cask.",
                ),
            )
        case (.some, .some):
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Analytics entry cannot include both formula and cask.",
                ),
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case formula
        case cask
        case count
    }

    private static func trimmedOrNil(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

private extension KeyedDecodingContainer {
    nonisolated func decodeRequiredIntLossy(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let stringValue = try? decode(String.self, forKey: key) {
            let digitsOnly = stringValue.filter(\.isNumber)
            if let parsedValue = Int(digitsOnly) {
                return parsedValue
            }
        }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected an integer-compatible analytics count.",
        )
    }

    nonisolated func decodeNonEmptyString(forKey key: Key) throws -> String {
        let value = try decode(String.self, forKey: key)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "Expected non-empty string.",
            )
        }
        return trimmed
    }
}
