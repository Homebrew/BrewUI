//
//  NavigationEnvironment.swift
//  BrewAppEnvironment
//

import BrewCore
import SwiftUI

public extension EnvironmentValues {
    /// Opens a package in the Installed tab, switching the sidebar if needed.
    /// Injected by `MainWindowView`; the default is a no-op so previews and
    /// unit tests don't have to provide it.
    @Entry var navigateToInstalledPackage: @MainActor (InstalledBrewPackage.ID) -> Void = { _ in }
}
