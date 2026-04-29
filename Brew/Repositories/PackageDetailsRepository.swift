//
//  PackageDetailsRepository.swift
//  Brew
//

import Foundation

protocol PackageDetailsRepository: Sendable {
    func loadPackageDetails(
        named name: String,
        preferredKind: InstalledPackageKind?,
    ) async throws -> InstalledPackageDetails
}

extension PackageDetailsRepository {
    func loadPackageDetails(named name: String) async throws -> InstalledPackageDetails {
        try await loadPackageDetails(named: name, preferredKind: nil)
    }
}

enum PackageDetailsRepositoryError: Error, Equatable {
    case packageNotFound(name: String)
    case invalidJSONOutput
}
