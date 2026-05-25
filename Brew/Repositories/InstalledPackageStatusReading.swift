//
//  InstalledPackageStatusReading.swift
//  Brew
//

import Foundation

/// Synchronous installed-status lookups for row rendering. Backed by the observable inventory source of
/// truth, so reads stay reactive when accessed from a SwiftUI view body.
@MainActor
protocol InstalledPackageStatusReading: Sendable {
    func isInstalled(_ id: HomebrewPackageID) -> Bool
    func info(for id: HomebrewPackageID) -> InstalledBrewPackage?
}
