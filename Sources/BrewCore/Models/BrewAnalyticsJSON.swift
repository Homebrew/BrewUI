//
//  BrewAnalyticsJSON.swift
//  BrewCore
//

import Foundation

/// Supported Homebrew analytics windows used by Discover.
public enum BrewAnalyticsWindow: String, CaseIterable, Sendable {
    case days30 = "30d"
    case days90 = "90d"
}

/// Faithful mirror of a Homebrew analytics API response. Decoding is field-for-field with the wire
/// shape; the flatten/validate/rank transformation lives in ``rankedPackageCounts()``.
public struct BrewAnalyticsJSON: Decodable, Sendable {
    public let category: String
    public let totalItems: Int
    public let totalCount: Int
    public let startDate: String
    public let endDate: String

    // The cask-install endpoint reuses the `formulae` key, so kind is read from each entry, not the bucket.
    let formulae: [String: [Entry]]?
    let casks: [String: [Entry]]?

    /// `count` is the comma-grouped string Homebrew sends ("1,234,567"); the API carries no rank field.
    struct Entry: Decodable {
        let formula: String?
        let cask: String?
        let count: String
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

// MARK: - Mapping

/// Raised while mapping a decoded analytics response into domain package counts.
public enum BrewAnalyticsMappingError: Error, Equatable {
    case missingPackageBucket
    case emptyPackageEntries(key: String)
    case missingPackageIdentity
    case conflictingPackageIdentity
    case malformedCount(String)
}

public extension BrewAnalyticsJSON {
    /// Package counts ranked by install count (descending, name tie-break). The API carries no rank
    /// field, so `count` is the only ranking signal. Every key must carry an entry: an empty array
    /// throws rather than being dropped, so a malformed payload can't silently shrink the ranking.
    func rankedPackageCounts() throws -> [BrewAnalyticsPackageCount] {
        guard let bucket = formulae ?? casks else {
            throw BrewAnalyticsMappingError.missingPackageBucket
        }
        return try bucket
            .map { key, entries in
                guard let entry = entries.first else {
                    throw BrewAnalyticsMappingError.emptyPackageEntries(key: key)
                }
                return try entry.packageCount()
            }
            .sorted(by: BrewAnalyticsPackageCount.byInstallCountDescendingThenName)
    }
}

public struct BrewAnalyticsPackageCount: Hashable, Sendable {
    public let reference: HomebrewPackageID
    public let count: Int

    public var name: String {
        reference.name
    }

    public init(reference: HomebrewPackageID, count: Int) {
        self.reference = reference
        self.count = count
    }

    static func byInstallCountDescendingThenName(
        _ lhs: BrewAnalyticsPackageCount,
        _ rhs: BrewAnalyticsPackageCount,
    ) -> Bool {
        if lhs.count == rhs.count {
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return lhs.count > rhs.count
    }
}

private extension BrewAnalyticsJSON.Entry {
    func packageCount() throws -> BrewAnalyticsPackageCount {
        try BrewAnalyticsPackageCount(reference: reference(), count: parsedCount())
    }

    func reference() throws -> HomebrewPackageID {
        let formulaName = Self.trimmedOrNil(formula)
        let caskToken = Self.trimmedOrNil(cask)

        switch (formulaName, caskToken) {
        case let (.some(name), nil):
            return .formula(name: name)
        case let (nil, .some(token)):
            return .cask(token: token)
        case (.none, .none):
            throw BrewAnalyticsMappingError.missingPackageIdentity
        case (.some, .some):
            throw BrewAnalyticsMappingError.conflictingPackageIdentity
        }
    }

    /// Strip the wire's group separators ("1,234" → 1234) before parsing.
    func parsedCount() throws -> Int {
        let digitsOnly = count.filter(\.isNumber)
        guard !digitsOnly.isEmpty, let value = Int(digitsOnly) else {
            throw BrewAnalyticsMappingError.malformedCount(count)
        }
        return value
    }

    static func trimmedOrNil(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
