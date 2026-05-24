//
//  InstalledPackagesRepositoryEnvironment.swift
//  Brew
//

import SwiftUI

extension EnvironmentValues {
    /// App-scoped installed-inventory source of truth. Injected at the nearest common ancestor of the
    /// Installed and Discover tabs (``MainWindowView``); read with `@Environment(\.installedPackagesRepository)`.
    /// The default is an inert placeholder for previews and unscoped subtrees.
    @Entry var installedPackagesRepository = BrewInstalledPackagesRepository.placeholder()
}
