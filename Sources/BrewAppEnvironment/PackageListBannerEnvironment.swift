//
//  PackageListBannerEnvironment.swift
//  BrewAppEnvironment
//

import SwiftUI

/// Chrome the app shell pins above a package list, inside the list column and outside its filtered dataset.
///
/// The lists render whatever is here without knowing what it is, which is what keeps one feature from
/// importing another: the self-upgrade banner is composed in `MainWindowView`, the one place that already
/// knows every feature exists.
public struct PackageListBanner {
    private let content: @MainActor () -> AnyView

    /// Erased because an environment value cannot carry an opaque type. It is one banner, rebuilt only when
    /// what it observes changes.
    public init(@ViewBuilder _ content: @escaping @MainActor () -> some View) {
        self.content = { AnyView(content()) }
    }

    @MainActor
    public func callAsFunction() -> some View {
        content()
    }
}

public extension EnvironmentValues {
    /// Injected by `MainWindowView`; the default is empty so previews and unit tests don't have to provide it.
    @Entry var packageListBanner = PackageListBanner { EmptyView() }
}
