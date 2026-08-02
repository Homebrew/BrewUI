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

/// Thin, faithful mirror of a Homebrew analytics API response. Decoding stays dumb — field-for-field
/// with the wire shape (synthesized `Decodable`, snake_case keys only) — and the flatten/validate/rank
/// transformation lives in ``rankedPackageCounts()`` rather than in `init(from:)`.
public struct BrewAnalyticsJSON: Decodable, Sendable {
    public let category: String
    public let totalItems: Int
    public let totalCount: Int
    public let startDate: String
    public let endDate: String

    /// Homebrew keys the ranking under a package-name → single-entry-array map. The cask-install
    /// endpoint reuses the `formulae` key, so kind is taken from each entry, not the bucket name.
    let formulae: [String: [Entry]]?
    let casks: [String: [Entry]]?

    /// A single analytics row. Mirrors the wire verbatim: `count` is the comma-grouped string Homebrew
    /// sends ("1,234,567"), parsed to an `Int` only during mapping.
    struct Entry: Decodable {
        let number: Int
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
    case missingPackageIdentity
    case conflictingPackageIdentity
    case malformedCount(String)
}

public extension BrewAnalyticsJSON {
    /// Flattens the keyed buckets into package counts in the backend's published rank order (`number`).
    /// The client never re-ranks by install count — it defers to the server's ordering, including the
    /// server's own tie-breaking.
    func rankedPackageCounts() throws -> [BrewAnalyticsPackageCount] {
        guard let bucket = formulae ?? casks else {
            throw BrewAnalyticsMappingError.missingPackageBucket
        }
        return try bucket.values
            .compactMap(\.first)
            .map { try $0.packageCount() }
            .sorted { $0.rank < $1.rank }
    }
}

public struct BrewAnalyticsPackageCount: Hashable, Sendable {
    public let reference: HomebrewPackageID
    public let count: Int
    /// The backend's `number` field — the authoritative rank used to order counts.
    public let rank: Int

    public var name: String {
        reference.name
    }

    public init(reference: HomebrewPackageID, count: Int, rank: Int) {
        self.reference = reference
        self.count = count
        self.rank = rank
    }
}

private extension BrewAnalyticsJSON.Entry {
    func packageCount() throws -> BrewAnalyticsPackageCount {
        try BrewAnalyticsPackageCount(reference: reference(), count: parsedCount(), rank: number)
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

    /// Strips the wire's group separators ("1,234" → 1234); mirrors the old lossy count decode.
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
