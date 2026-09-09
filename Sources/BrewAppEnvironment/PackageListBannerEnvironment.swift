//
//  PackageListBannerEnvironment.swift
//  BrewAppEnvironment
//

import SwiftUI

/// Chrome the app shell pins above a package list, inside the list column and outside its filtered dataset.
/// The lists render it without naming it, which is what stops one feature importing another.
public struct PackageListBanner {
    private let content: @MainActor () -> AnyView

    /// Erased because an environment value cannot carry an opaque type.
    public init(@ViewBuilder _ content: @escaping @MainActor () -> some View) {
        self.content = { AnyView(content()) }
    }

    @MainActor
    public func callAsFunction() -> some View {
        content()
    }
}

public extension EnvironmentValues {
    @Entry var packageListBanner = PackageListBanner { EmptyView() }
}
